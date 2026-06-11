import SwiftUI

struct MetricsPopoverView: View {
    @ObservedObject var viewModel: AppViewModel
    var onOpenPanel: () -> Void

    private var lang: AppLanguage { viewModel.language }
    private var theme: MonitorTheme { viewModel.theme }

    var body: some View {
        VStack(spacing: 14) {
            header
            ringSection
            SparklineView(values: viewModel.cpuHistory, color: theme.primary, height: 28)
            statRow

            if !viewModel.anomalies.isEmpty {
                anomalyCTA
            }

            topProcessesSection

            Button(action: onOpenPanel) {
                Text(L10n.tr("open_panel", lang))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(MonitorPrimaryButton(theme: theme))

            Text(L10n.tr("double_click_hint", lang))
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(theme.textTertiary)
                .multilineTextAlignment(.center)
        }
        .padding(18)
        .frame(width: 312)
        .background(theme.windowMaterial)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(theme.primary)
                .frame(width: 28, height: 28)
                .background(
                    theme.primary.opacity(0.16),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
            Text("Activity Guard")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(theme.textPrimary)
            Spacer()
            MonitorStatusBadge(
                active: viewModel.isMonitoring,
                theme: theme,
                label: ""
            )
        }
    }

    private var ringSection: some View {
        VStack(spacing: 6) {
            RingProgressView(
                progress: viewModel.systemCPU.total / 100,
                theme: theme,
                size: 96
            )
            Text(L10n.tr("cpu_usage", lang))
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(theme.textTertiary)
        }
    }

    private var statRow: some View {
        HStack(spacing: 0) {
            miniStat("\(viewModel.displayedProcesses.count)", L10n.tr("process_count", lang))
            divider
            miniStat(
                "\(viewModel.anomalies.count)",
                L10n.tr("anomaly_count", lang),
                color: viewModel.anomalies.isEmpty ? theme.textPrimary : theme.danger
            )
            divider
            miniStat(
                String(format: "%.0f", viewModel.systemCPU.idle),
                L10n.tr("idle", lang),
                color: theme.success
            )
        }
        .padding(.vertical, 10)
        .background(theme.cardTint, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(theme.cardBorder)
        )
    }

    private var divider: some View {
        Rectangle()
            .fill(theme.cardBorder)
            .frame(width: 1, height: 28)
    }

    private var anomalyCTA: some View {
        Button {
            onOpenPanel()
            viewModel.openAnomalyProcesses()
        } label: {
            HStack {
                Image(systemName: "bell.badge.fill")
                    .foregroundStyle(theme.warning)
                Text(L10n.tr("view_anomaly_processes", lang))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                Spacer()
                Text("\(viewModel.anomalies.count)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(theme.danger)
                    .monospacedDigit()
            }
            .padding(10)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .background(theme.warning.opacity(0.18), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(theme.warning.opacity(0.35))
            )
        }
        .buttonStyle(.plain)
    }

    private var topProcessesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(L10n.tr("top_processes", lang))
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(theme.textTertiary)
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 6)

            ForEach(Array(viewModel.topProcesses.prefix(3).enumerated()), id: \.element.id) { index, proc in
                if index > 0 {
                    Divider()
                        .overlay(theme.cardBorder)
                        .padding(.horizontal, 12)
                }
                MonitorCompactProcessRow(process: proc, theme: theme)
            }
        }
        .background(theme.cardTint, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .background(theme.cardMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(theme.cardBorder)
        )
    }

    private func miniStat(_ value: String, _ label: String, color: Color? = nil) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(color ?? theme.textPrimary)
                .monospacedDigit()
            Text(label)
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(theme.textTertiary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
}
