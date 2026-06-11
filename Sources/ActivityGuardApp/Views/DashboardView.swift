import SwiftUI

struct DashboardView: View {
    @ObservedObject var viewModel: AppViewModel

    private var lang: AppLanguage { viewModel.language }
    private var theme: MonitorTheme { viewModel.theme }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(theme.windowMaterial)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    statusHeader
                    kpiGrid
                    topProcessSection
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }
            .scrollIndicators(.hidden)
        }
        .foregroundStyle(theme.textPrimary)
    }

    // MARK: - Status Header (F-top)

    private var statusHeader: some View {
        HStack(spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(theme.primary)
                    .frame(width: 36, height: 36)
                    .background(
                        theme.primary.opacity(0.16),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text("Activity Guard")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(theme.textPrimary)
                    MonitorStatusBadge(
                        active: viewModel.isMonitoring,
                        theme: theme,
                        label: viewModel.isMonitoring
                            ? L10n.tr("monitoring_active", lang)
                            : L10n.tr("monitoring_paused", lang)
                    )
                }
            }

            Spacer()

            HStack(spacing: 8) {
                Button { viewModel.refreshNow() } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(MonitorGhostButton(theme: theme))
                .help(L10n.tr("refresh", lang))

                Button { viewModel.openProcessList() } label: {
                    Label(L10n.tr("detail", lang), systemImage: "list.bullet.rectangle")
                }
                .buttonStyle(MonitorPrimaryButton(theme: theme))
            }
        }
        .monitorCard(theme)
    }

    // MARK: - KPI Grid

    private var kpiGrid: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 280, maximum: .infinity), spacing: 16)],
            alignment: .leading,
            spacing: 16
        ) {
            cpuCard
            memoryCard
            gpuCard
            networkCard
            powerCard
            processCard
            anomalyCard
            summaryCard
        }
    }

    private var cpuCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            MonitorCardHeader(icon: "cpu", title: L10n.tr("cpu_usage", lang), theme: theme)

            HStack(spacing: 16) {
                RingProgressView(
                    progress: viewModel.systemCPU.total / 100,
                    theme: theme,
                    size: 68
                )

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(String(format: "%.1f", viewModel.systemCPU.total))
                            .font(.system(size: 32, weight: .semibold, design: .rounded))
                            .foregroundStyle(theme.textPrimary)
                            .monospacedDigit()
                        Text("%")
                            .font(.system(size: 12))
                            .foregroundStyle(theme.textTertiary)
                    }

                    StackedCPUBar(
                        user: viewModel.systemCPU.user,
                        system: viewModel.systemCPU.system,
                        idle: viewModel.systemCPU.idle,
                        theme: theme
                    )

                    HStack(spacing: 12) {
                        legendDot(theme.primary, L10n.tr("user", lang), viewModel.systemCPU.user)
                        legendDot(theme.cyan, L10n.tr("system", lang), viewModel.systemCPU.system)
                    }
                }
            }

            Spacer(minLength: 0)

            SparklineView(values: viewModel.cpuHistory, color: theme.primary, height: 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .monitorCard(theme, stretch: true)
    }

    private var memoryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            MonitorCardHeader(icon: "memorychip", title: L10n.tr("memory_usage", lang), theme: theme)

            HStack(spacing: 16) {
                RingProgressView(
                    progress: viewModel.systemMemory.usedPercent / 100,
                    theme: theme,
                    size: 68
                )

                VStack(alignment: .leading, spacing: 6) {
                    metricLine(
                        L10n.tr("memory_used", lang),
                        viewModel.formatMemoryBytes(viewModel.systemMemory.used),
                        theme.textPrimary
                    )
                    metricLine(
                        L10n.tr("memory_free", lang),
                        viewModel.formatMemoryBytes(viewModel.systemMemory.free),
                        theme.success
                    )
                    metricLine(
                        L10n.tr("memory_total", lang),
                        viewModel.formatMemoryBytes(viewModel.systemMemory.total),
                        theme.textSecondary
                    )
                }
            }

            Spacer(minLength: 0)

            SparklineView(values: viewModel.memoryHistory, color: theme.cyan, height: 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .monitorCard(theme, stretch: true)
    }

    private var gpuCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            MonitorCardHeader(icon: "display", title: L10n.tr("gpu_usage", lang), theme: theme)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(String(format: "%.1f", viewModel.systemGPU.utilization))
                    .font(.system(size: 32, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.textPrimary)
                    .monospacedDigit()
                Text("%")
                    .font(.system(size: 12))
                    .foregroundStyle(theme.textTertiary)
            }

            MiniProgressBar(
                value: viewModel.systemGPU.utilization,
                maxValue: 100,
                color: theme.warning,
                trackColor: theme.progressTrack
            )

            Spacer(minLength: 0)

            SparklineView(values: viewModel.gpuHistory, color: theme.warning, height: 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .monitorCard(theme, stretch: true)
    }

    private var networkCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            MonitorCardHeader(icon: "network", title: L10n.tr("network_usage", lang), theme: theme)

            HStack(spacing: 16) {
                networkStat(
                    icon: "arrow.down.circle.fill",
                    label: L10n.tr("download", lang),
                    value: NetworkThroughput.formatRate(viewModel.systemNetwork.bytesInPerSec) + "/s",
                    color: theme.primary
                )
                networkStat(
                    icon: "arrow.up.circle.fill",
                    label: L10n.tr("upload", lang),
                    value: NetworkThroughput.formatRate(viewModel.systemNetwork.bytesOutPerSec) + "/s",
                    color: theme.cyan
                )
            }

            Spacer(minLength: 0)

            SparklineView(values: viewModel.networkHistory, color: theme.primary, height: 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .monitorCard(theme, stretch: true)
    }

    private var powerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            MonitorCardHeader(icon: "bolt.fill", title: L10n.tr("power_usage", lang), theme: theme, tint: theme.warning)

            HStack(spacing: 8) {
                Image(systemName: thermalIcon(viewModel.systemPower.thermal))
                    .foregroundStyle(thermalColor(viewModel.systemPower.thermal))
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.tr("thermal_state", lang))
                        .font(.system(size: 11))
                        .foregroundStyle(theme.textTertiary)
                    Text(thermalLabel(viewModel.systemPower.thermal))
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(thermalColor(viewModel.systemPower.thermal))
                }
            }

            HStack {
                Image(systemName: viewModel.systemPower.isOnACPower ? "powerplug.fill" : "battery.100")
                    .foregroundStyle(theme.textSecondary)
                Text(viewModel.systemPower.powerSourceLabel)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(theme.textPrimary)
                Spacer()
                if let level = viewModel.systemPower.batteryLevel {
                    Text(String(format: "%.0f%%", level))
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(theme.textSecondary)
                        .monospacedDigit()
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .monitorCard(theme, highlight: viewModel.systemPower.thermal == .serious || viewModel.systemPower.thermal == .critical, stretch: true)
    }

    private func metricLine(_ label: String, _ value: String, _ color: Color) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(theme.textTertiary)
            Spacer()
            Text(value)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(color)
        }
    }

    private func networkStat(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundStyle(color)
                Text(label)
                    .font(.system(size: 11))
                    .foregroundStyle(theme.textTertiary)
            }
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundStyle(theme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func thermalLabel(_ level: SystemPower.ThermalLevel) -> String {
        switch level {
        case .nominal: return L10n.tr("thermal_nominal", lang)
        case .fair: return L10n.tr("thermal_fair", lang)
        case .serious: return L10n.tr("thermal_serious", lang)
        case .critical: return L10n.tr("thermal_critical", lang)
        }
    }

    private func thermalIcon(_ level: SystemPower.ThermalLevel) -> String {
        switch level {
        case .nominal: return "thermometer.low"
        case .fair: return "thermometer.medium"
        case .serious: return "thermometer.high"
        case .critical: return "flame.fill"
        }
    }

    private func thermalColor(_ level: SystemPower.ThermalLevel) -> Color {
        switch level {
        case .nominal: return theme.success
        case .fair: return theme.primary
        case .serious: return theme.warning
        case .critical: return theme.danger
        }
    }

    private func legendDot(_ color: Color, _ label: String, _ value: Double) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(theme.textTertiary)
            Text(String(format: "%.0f%%", value))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(theme.textSecondary)
                .monospacedDigit()
        }
    }

    private var processCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            MonitorCardHeader(icon: "gearshape.2", title: L10n.tr("process_count", lang), theme: theme)

            Text("\(viewModel.displayedProcesses.count)")
                .font(.system(size: 32, weight: .semibold, design: .rounded))
                .foregroundStyle(theme.textPrimary)
                .monospacedDigit()

            Text(L10n.tr("total_processes", lang))
                .font(.system(size: 12))
                .foregroundStyle(theme.textTertiary)

            Spacer(minLength: 0)

            Button { viewModel.openAnomalyProcesses() } label: {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(viewModel.anomalies.isEmpty ? theme.textTertiary : theme.danger)
                    Text("\(viewModel.anomalies.count)")
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundStyle(viewModel.anomalies.isEmpty ? theme.textSecondary : theme.danger)
                        .monospacedDigit()
                    Text(L10n.tr("anomaly_count", lang))
                        .font(.system(size: 12))
                        .foregroundStyle(theme.textTertiary)
                    Spacer()
                    if !viewModel.anomalies.isEmpty {
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(theme.textTertiary)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(viewModel.anomalies.isEmpty)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .monitorCard(theme, stretch: true)
    }

    private var anomalyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            MonitorCardHeader(
                icon: "bell.badge.fill",
                title: L10n.tr("anomaly_alerts", lang),
                theme: theme,
                tint: anomalyCardTint
            )

            if viewModel.anomalies.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(theme.success)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.tr("no_anomalies", lang))
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                        Text(L10n.tr("system_healthy", lang))
                            .font(.system(size: 12))
                            .foregroundStyle(theme.textTertiary)
                    }
                }
            } else {
                ForEach(AnomalyKind.allCases, id: \.self) { kind in
                    let count = viewModel.anomalyCounts[kind] ?? 0
                    if count > 0 {
                        Button { viewModel.openAnomalyProcesses(kind: kind) } label: {
                            HStack {
                                Image(systemName: kind.icon)
                                    .font(.system(size: 11))
                                    .foregroundStyle(kindColor(kind))
                                    .frame(width: 14)
                                Text(kind.localizedName)
                                    .font(.system(size: 13, design: .rounded))
                                    .foregroundStyle(theme.textPrimary)
                                Spacer()
                                Text("\(count)")
                                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(kindColor(kind))
                                    .monospacedDigit()
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(kindColor(kind).opacity(0.15), in: Capsule())
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                Button(L10n.tr("view_anomaly_processes", lang)) { viewModel.openAnomalyProcesses() }
                    .buttonStyle(MonitorPrimaryButton(theme: theme))
                    .frame(maxWidth: .infinity)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .monitorCard(theme, highlight: !viewModel.anomalies.isEmpty, stretch: true)
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            MonitorCardHeader(icon: "flame.fill", title: L10n.tr("top_consumer", lang), theme: theme, tint: theme.warning)

            if let top = viewModel.topProcesses.first, top.cpuPercent > 0 {
                Text(top.name)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .foregroundStyle(theme.textPrimary)

                HStack {
                    Text(String(format: "%.1f%% CPU", top.cpuPercent))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(theme.cpuColor(for: top.cpuPercent))
                        .monospacedDigit()
                    Text(top.rssFormatted)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(theme.textSecondary)
                }

                MiniProgressBar(
                    value: top.cpuPercent,
                    maxValue: 100,
                    color: theme.cpuColor(for: top.cpuPercent),
                    trackColor: theme.progressTrack
                )
            } else {
                Text(L10n.tr("monitoring_paused", lang))
                    .font(.system(size: 13))
                    .foregroundStyle(theme.textTertiary)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .monitorCard(theme, stretch: true)
    }

    // MARK: - Bottom Process List (F-bottom)

    private var topProcessSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L10n.tr("top_processes", lang))
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.textPrimary)
                Spacer()
                Button(L10n.tr("view_all", lang)) { viewModel.openProcessList() }
                    .buttonStyle(MonitorGhostButton(theme: theme))
            }

            VStack(spacing: 0) {
                listHeader
                ForEach(viewModel.topProcesses, id: \.id) { proc in
                    MonitorProcessRow(
                        process: proc,
                        theme: theme,
                        anomaly: viewModel.anomalies.first { $0.pid == proc.pid }
                    )
                }
                .padding(.vertical, 2)
            }
            .padding(.vertical, 4)
            .background(theme.cardTint, in: MonitorTheme.cardShape)
            .background(theme.cardMaterial, in: MonitorTheme.cardShape)
            .overlay(MonitorTheme.cardShape.stroke(theme.cardBorder))
            .shadow(color: .black.opacity(theme.scheme == .dark ? 0.18 : 0.05), radius: 6, y: 2)
        }
    }

    private var listHeader: some View {
        HStack(spacing: 12) {
            Text(L10n.tr("process", lang))
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("CPU")
                .frame(width: 52, alignment: .trailing)
            Text(L10n.tr("cpu_time", lang))
                .frame(width: 64, alignment: .trailing)
            Text(L10n.tr("threads", lang))
                .frame(width: 40, alignment: .trailing)
            Text(L10n.tr("memory", lang))
                .frame(width: 72, alignment: .trailing)
        }
        .font(.system(size: 11, weight: .medium, design: .rounded))
        .foregroundStyle(theme.textTertiary)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(theme.headerBackground)
        .overlay(alignment: .bottom) {
            Rectangle().fill(theme.cardBorder).frame(height: 1)
        }
    }

    private var anomalyCardTint: Color {
        guard !viewModel.anomalies.isEmpty else { return theme.textSecondary }
        let hasCritical = viewModel.anomalies.contains { anomaly in
            switch anomaly.kind {
            case .zombie, .highCPU: return true
            case .memoryLeak: return anomaly.memoryLeakSeverity == .severe
            case .highEnergy: return false
            }
        }
        return hasCritical ? theme.danger : theme.warning
    }

    private func kindColor(_ kind: AnomalyKind) -> Color {
        switch kind {
        case .highCPU: return theme.danger
        case .memoryLeak:
            let hasSevere = viewModel.anomalies.contains {
                $0.kind == .memoryLeak && $0.memoryLeakSeverity == .severe
            }
            return hasSevere ? theme.danger : theme.warning
        case .zombie: return theme.textTertiary
        case .highEnergy: return theme.warning
        }
    }
}
