import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var notificationStatusText: String = ""
    @State private var isTestingNotification = false

    private var theme: MonitorTheme { viewModel.theme }
    private var lang: AppLanguage { viewModel.language }

    var body: some View {
        VStack(spacing: 0) {
            headerBar

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    generalSection
                    anomalySection
                    notificationsSection
                    temperatureSection
                    rulesSection
                    testNotificationSection
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }

            footerBar
        }
        .frame(width: 560, height: 720)
        .background(theme.background)
        .task {
            viewModel.refreshLaunchAtLoginStatus()
            await refreshNotificationStatus()
        }
    }

    // MARK: - Chrome

    private var headerBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "gearshape.2.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(theme.primary)
                .frame(width: 36, height: 36)
                .background(theme.primary.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.tr("settings", lang))
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.textPrimary)
                Text(L10n.tr("settings_subtitle", lang))
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(theme.textTertiary)
            }

            Spacer()

            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(theme.textTertiary)
            }
            .buttonStyle(.plain)
            .help(L10n.tr("confirm", lang))
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
        .background(theme.headerBackground)
        .overlay(alignment: .bottom) {
            Rectangle().fill(theme.cardBorder).frame(height: 1)
        }
    }

    private var footerBar: some View {
        HStack {
            Spacer()
            Button(L10n.tr("confirm", lang)) { dismiss() }
                .buttonStyle(MonitorPrimaryButton(theme: theme))
                .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(theme.headerBackground)
        .overlay(alignment: .top) {
            Rectangle().fill(theme.cardBorder).frame(height: 1)
        }
    }

    // MARK: - Sections

    private var generalSection: some View {
        settingsCard {
            VStack(alignment: .leading, spacing: 18) {
                sectionHeader(icon: "slider.horizontal.3", title: "settings_section_general")

                settingsFieldLabel("theme")
                optionRow {
                    ForEach(MonitorColorScheme.allCases) { scheme in
                        optionChip(
                            scheme.localizedName(lang),
                            value: scheme,
                            selection: $viewModel.colorScheme
                        )
                    }
                }

                settingsFieldLabel("language")
                optionRow {
                    ForEach(AppLanguage.allCases, id: \.self) { appLang in
                        optionChip(appLang.displayName, value: appLang, selection: $viewModel.language)
                    }
                }

                Divider().overlay(theme.cardBorder)

                toggleRow("launch_at_login", isOn: Binding(
                    get: { viewModel.launchAtLoginEnabled },
                    set: { viewModel.setLaunchAtLogin($0) }
                ))
                hint("launch_at_login_hint")

                settingsFieldLabel("menu_bar_display")
                optionGrid {
                    ForEach(MenuBarMetric.allCases) { metric in
                        optionChip(
                            metric.localizedName(lang),
                            value: metric,
                            selection: Binding(
                                get: { viewModel.menuBarMetric },
                                set: { viewModel.menuBarMetric = $0 }
                            )
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                hint("menu_bar_display_hint")
            }
        }
    }

    private var anomalySection: some View {
        settingsCard {
            VStack(alignment: .leading, spacing: 18) {
                sectionHeader(icon: "waveform.path.ecg", title: "settings_section_anomaly")

                stepperField(
                    title: "anomaly_persistence",
                    valueLabel: L10n.tr("anomaly_persistence_value", lang, viewModel.anomalyPersistenceSeconds),
                    value: $viewModel.anomalyPersistenceSeconds,
                    range: AnomalyStabilizer.minPersistenceSeconds...AnomalyStabilizer.maxPersistenceSeconds,
                    step: 1
                )
                hint("anomaly_persistence_hint")

                Divider().overlay(theme.cardBorder)

                stepperField(
                    title: "memory_leak_severe_threshold",
                    valueLabel: L10n.tr("memory_leak_severe_threshold_value", lang, viewModel.memoryLeakSevereGrowthMB),
                    value: $viewModel.memoryLeakSevereGrowthMB,
                    range: MemoryLeakConfig.severeGrowthThresholdRange,
                    step: MemoryLeakConfig.severeGrowthThresholdStepMB
                )
                hint("memory_leak_severe_threshold_hint")

                Divider().overlay(theme.cardBorder)

                settingsFieldLabel("memory_leak_whitelist")
                TextField(
                    L10n.tr("memory_leak_whitelist_placeholder", lang),
                    text: $viewModel.memoryLeakWhitelistText,
                    axis: .vertical
                )
                .textFieldStyle(.plain)
                .font(.system(size: 13, design: .rounded))
                .padding(10)
                .frame(minHeight: 72)
                .background(theme.rowHover.opacity(0.6), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(theme.cardBorder, lineWidth: 1)
                )
                hint("memory_leak_whitelist_hint")
            }
        }
    }

    private var notificationsSection: some View {
        settingsCard {
            VStack(alignment: .leading, spacing: 18) {
                sectionHeader(icon: "bell.badge.fill", title: "settings_section_notifications")

                toggleRow("anomaly_notifications", isOn: $viewModel.anomalyNotificationsEnabled)

                if viewModel.anomalyNotificationsEnabled {
                    settingsFieldLabel("notification_interval")
                    Picker("", selection: $viewModel.notificationIntervalSeconds) {
                        ForEach(NotificationInterval.allCases) { interval in
                            Text(interval.localizedLabel(lang)).tag(interval.rawValue)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(maxWidth: 220, alignment: .leading)

                    hint("notification_interval_hint")
                    hint("notification_zombie_only_hint")
                }
            }
        }
    }

    private var temperatureSection: some View {
        settingsCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(icon: "thermometer.medium", title: "settings_section_temperature")

                toggleRow("temperature_notifications", isOn: $viewModel.temperatureNotificationsEnabled)
                hint("temperature_notifications_hint")
            }
        }
    }

    private var rulesSection: some View {
        settingsCard {
            VStack(alignment: .leading, spacing: 10) {
                sectionHeader(icon: "list.bullet.clipboard", title: "settings_section_rules")

                Text(L10n.tr("anomaly_rules_hint", lang))
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(theme.textSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var testNotificationSection: some View {
        settingsCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(icon: "paperplane.fill", title: "settings_section_test")

                HStack(spacing: 12) {
                    Button {
                        Task { await testNotification() }
                    } label: {
                        HStack(spacing: 8) {
                            if isTestingNotification {
                                ProgressView().controlSize(.small)
                            }
                            Text(L10n.tr("test_notification", lang))
                        }
                    }
                    .buttonStyle(MonitorPrimaryButton(theme: theme))
                    .disabled(isTestingNotification)

                    if !notificationStatusText.isEmpty {
                        Text(notificationStatusText)
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    // MARK: - Building blocks

    private func settingsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.cardTint, in: MonitorTheme.cardShape)
            .background(theme.cardMaterial, in: MonitorTheme.cardShape)
            .overlay(MonitorTheme.cardShape.stroke(theme.cardBorder, lineWidth: 1))
    }

    private func sectionHeader(icon: String, title: String) -> some View {
        MonitorCardHeader(icon: icon, title: L10n.tr(title, lang), theme: theme)
    }

    private func settingsFieldLabel(_ key: String) -> some View {
        Text(L10n.tr(key, lang))
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(theme.textPrimary)
    }

    private func hint(_ key: String) -> some View {
        Text(L10n.tr(key, lang))
            .font(.system(size: 12, design: .rounded))
            .foregroundStyle(theme.textTertiary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func toggleRow(_ key: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(L10n.tr(key, lang))
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(theme.textPrimary)
        }
        .toggleStyle(.switch)
    }

    private func optionRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 8) {
            content()
            Spacer(minLength: 0)
        }
    }

    private func optionGrid<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
            alignment: .leading,
            spacing: 8
        ) {
            content()
        }
    }

    private func optionChip<T: Hashable>(
        _ title: String,
        value: T,
        selection: Binding<T>
    ) -> some View {
        let selected = selection.wrappedValue == value
        return Button { selection.wrappedValue = value } label: {
            Text(title)
                .font(.system(size: 13, weight: selected ? .semibold : .regular, design: .rounded))
                .foregroundStyle(selected ? theme.primary : theme.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    selected ? theme.primary.opacity(0.14) : theme.rowHover.opacity(0.55),
                    in: MonitorTheme.buttonShape
                )
                .overlay(
                    MonitorTheme.buttonShape.stroke(
                        selected ? theme.primary.opacity(0.35) : theme.cardBorder,
                        lineWidth: 1
                    )
                )
        }
        .buttonStyle(.plain)
    }

    private func stepperField(
        title: String,
        valueLabel: String,
        value: Binding<Int>,
        range: ClosedRange<Int>,
        step: Int
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            settingsFieldLabel(title)
            HStack {
                Text(valueLabel)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(theme.textSecondary)
                Spacer()
                Stepper("", value: value, in: range, step: step)
                    .labelsHidden()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(theme.rowHover.opacity(0.55), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(theme.cardBorder, lineWidth: 1)
            )
        }
    }

    // MARK: - Actions

    private func refreshNotificationStatus() async {
        let status = await AnomalyNotifier.shared.currentPermissionStatus()
        switch status {
        case .authorized:
            notificationStatusText = L10n.tr("notification_status_authorized", lang)
        case .denied:
            notificationStatusText = L10n.tr("notification_status_denied", lang)
        case .notDetermined:
            notificationStatusText = L10n.tr("notification_status_pending", lang)
        }
    }

    private func testNotification() async {
        isTestingNotification = true
        defer { isTestingNotification = false }

        let success = await AnomalyNotifier.shared.sendTestNotification(language: lang)
        if success {
            notificationStatusText = L10n.tr("test_notification_sent", lang)
        } else {
            let status = await AnomalyNotifier.shared.currentPermissionStatus()
            notificationStatusText = status == .denied
                ? L10n.tr("notification_status_denied", lang)
                : L10n.tr("test_notification_failed", lang)
        }
    }
}
