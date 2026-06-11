import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var notificationStatusText: String = ""
    @State private var isTestingNotification = false

    private var theme: MonitorTheme { viewModel.theme }

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "gearshape.2")
                .font(.title)
                .foregroundStyle(theme.primary)
            Text(L10n.tr("settings", viewModel.language))
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(theme.textPrimary)

            Form {
                Picker(L10n.tr("theme", viewModel.language), selection: $viewModel.colorScheme) {
                    ForEach(MonitorColorScheme.allCases) { scheme in
                        Text(scheme.localizedName(viewModel.language)).tag(scheme)
                    }
                }
                .pickerStyle(.radioGroup)

                Picker(L10n.tr("language", viewModel.language), selection: $viewModel.language) {
                    ForEach(AppLanguage.allCases, id: \.self) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
                .pickerStyle(.radioGroup)

                Toggle(L10n.tr("launch_at_login", viewModel.language), isOn: Binding(
                    get: { viewModel.launchAtLoginEnabled },
                    set: { viewModel.setLaunchAtLogin($0) }
                ))

                Text(L10n.tr("launch_at_login_hint", viewModel.language))
                    .font(.caption)
                    .foregroundStyle(theme.textTertiary)

                Picker(L10n.tr("menu_bar_display", viewModel.language), selection: Binding(
                    get: { viewModel.menuBarMetric },
                    set: { viewModel.menuBarMetric = $0 }
                )) {
                    ForEach(MenuBarMetric.allCases) { metric in
                        Text(metric.localizedName(viewModel.language)).tag(metric)
                    }
                }
                .pickerStyle(.radioGroup)

                Text(L10n.tr("menu_bar_display_hint", viewModel.language))
                    .font(.caption)
                    .foregroundStyle(theme.textTertiary)

                Toggle(L10n.tr("anomaly_notifications", viewModel.language), isOn: $viewModel.anomalyNotificationsEnabled)

                if viewModel.anomalyNotificationsEnabled {
                    Picker(L10n.tr("notification_interval", viewModel.language), selection: $viewModel.notificationIntervalSeconds) {
                        ForEach(NotificationInterval.allCases) { interval in
                            Text(interval.localizedLabel(viewModel.language))
                                .tag(interval.rawValue)
                        }
                    }
                    .pickerStyle(.menu)

                    Text(L10n.tr("notification_interval_hint", viewModel.language))
                        .font(.caption)
                        .foregroundStyle(theme.textTertiary)

                    Text(L10n.tr("notification_zombie_only_hint", viewModel.language))
                        .font(.caption)
                        .foregroundStyle(theme.textTertiary)
                }

                Toggle(L10n.tr("temperature_notifications", viewModel.language), isOn: $viewModel.temperatureNotificationsEnabled)

                Text(L10n.tr("temperature_notifications_hint", viewModel.language))
                    .font(.caption)
                    .foregroundStyle(theme.textTertiary)

                Section {
                    Text(L10n.tr("anomaly_rules_hint", viewModel.language))
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Button {
                        Task { await testNotification() }
                    } label: {
                        HStack {
                            if isTestingNotification {
                                ProgressView().controlSize(.small)
                            }
                            Text(L10n.tr("test_notification", viewModel.language))
                        }
                    }
                    .disabled(isTestingNotification)

                    if !notificationStatusText.isEmpty {
                        Text(notificationStatusText)
                            .font(.caption)
                            .foregroundStyle(theme.textSecondary)
                    }
                }
            }
            .formStyle(.grouped)
            .frame(width: 320)

            Button(L10n.tr("confirm", viewModel.language)) { dismiss() }
                .buttonStyle(MonitorPrimaryButton(theme: theme))
                .keyboardShortcut(.defaultAction)
        }
        .padding(24)
        .frame(width: 360)
        .background(theme.background)
        .task {
            viewModel.refreshLaunchAtLoginStatus()
            await refreshNotificationStatus()
        }
    }

    private func refreshNotificationStatus() async {
        let status = await AnomalyNotifier.shared.currentPermissionStatus()
        switch status {
        case .authorized:
            notificationStatusText = L10n.tr("notification_status_authorized", viewModel.language)
        case .denied:
            notificationStatusText = L10n.tr("notification_status_denied", viewModel.language)
        case .notDetermined:
            notificationStatusText = L10n.tr("notification_status_pending", viewModel.language)
        }
    }

    private func testNotification() async {
        isTestingNotification = true
        defer { isTestingNotification = false }

        let success = await AnomalyNotifier.shared.sendTestNotification(language: viewModel.language)
        if success {
            notificationStatusText = L10n.tr("test_notification_sent", viewModel.language)
        } else {
            let status = await AnomalyNotifier.shared.currentPermissionStatus()
            notificationStatusText = status == .denied
                ? L10n.tr("notification_status_denied", viewModel.language)
                : L10n.tr("test_notification_failed", viewModel.language)
        }
    }
}
