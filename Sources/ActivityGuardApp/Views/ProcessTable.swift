import SwiftUI

struct ProcessTable: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var killConfirmPID: Int32? = nil
    @State private var killConfirmName: String = ""

    private var theme: MonitorTheme { viewModel.theme }
    private var lang: AppLanguage { viewModel.language }

    var body: some View {
        let processes = viewModel.filteredProcessesList
        let maxRSS = processes.map(\.rss).max() ?? 1

        ZStack {
            Rectangle()
                .fill(theme.windowMaterial)
                .ignoresSafeArea()

            if processes.isEmpty && viewModel.showAnomaliesOnly {
                ContentUnavailableView(
                    L10n.tr("no_anomalies", lang),
                    systemImage: "checkmark.seal",
                    description: Text(L10n.tr("system_healthy", lang))
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                        Section {
                            ForEach(Array(processes.enumerated()), id: \.element.id) { index, proc in
                                processRow(proc, index: index, maxRSS: maxRSS)
                            }
                        } header: {
                            tableHeader
                        }
                    }
                    .background(theme.cardTint, in: MonitorTheme.cardShape)
                    .background(theme.cardMaterial, in: MonitorTheme.cardShape)
                    .overlay(MonitorTheme.cardShape.stroke(theme.cardBorder))
                    .shadow(color: .black.opacity(theme.scheme == .dark ? 0.22 : 0.06), radius: 10, y: 3)
                    .padding(24)
                }
                .scrollIndicators(.hidden)
            }
        }
        .alert(L10n.tr("kill_confirm_title", lang), isPresented: .init(
            get: { killConfirmPID != nil },
            set: { if !$0 { killConfirmPID = nil } }
        )) {
            Button(L10n.tr("cancel", lang), role: .cancel) { killConfirmPID = nil }
            Button(L10n.tr("confirm", lang), role: .destructive) {
                if let pid = killConfirmPID {
                    _ = viewModel.killProcess(pid: pid, processName: killConfirmName)
                }
                killConfirmPID = nil
            }
        } message: {
            if let pid = killConfirmPID {
                Text(L10n.tr("kill_confirm_message", lang, killConfirmName, pid))
            }
        }
    }

    private var tableHeader: some View {
        HStack(spacing: 8) {
            sortableHeader(L10n.tr("process", lang), field: .name, width: nil)
            if viewModel.showAnomaliesOnly {
                Text(L10n.tr("anomaly_type", lang)).frame(width: 80, alignment: .leading)
                Text(L10n.tr("anomaly_detail", lang)).frame(width: 120, alignment: .leading)
            }
            sortableHeader(L10n.tr("pid", lang), field: .pid, width: 56)
            sortableHeader("CPU", field: .cpu, width: 56)
            sortableHeader(L10n.tr("cpu_time", lang), field: .cpuTime, width: 72)
            sortableHeader(L10n.tr("threads", lang), field: .threads, width: 48)
            sortableHeader(L10n.tr("memory", lang), field: .memory, width: 72)
            Color.clear.frame(width: 28)
        }
        .font(.system(size: 11, weight: .medium, design: .rounded))
        .foregroundStyle(theme.textTertiary)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.thinMaterial)
        .overlay(alignment: .bottom) {
            Rectangle().fill(theme.cardBorder).frame(height: 1)
        }
    }

    @ViewBuilder
    private func sortableHeader(_ title: String, field: ProcessSortField, width: CGFloat?) -> some View {
        Button { viewModel.toggleSort(field) } label: {
            HStack(spacing: 2) {
                Text(title)
                if viewModel.processSortField == field {
                    Image(systemName: viewModel.processSortAscending ? "chevron.up" : "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(theme.primary)
                }
            }
            .frame(
                maxWidth: width == nil ? .infinity : nil,
                alignment: width == nil ? .leading : .trailing
            )
            .frame(width: width)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func processRow(_ proc: ProcessWithCPU, index: Int, maxRSS: UInt64) -> some View {
        ProcessTableRow(
            proc: proc,
            maxRSS: maxRSS,
            theme: theme,
            showAnomalies: viewModel.showAnomaliesOnly,
            anomaly: viewModel.anomaliesByPID[proc.pid],
            onKill: {
                killConfirmPID = proc.pid
                killConfirmName = proc.name
            }
        )
    }
}

private struct ProcessTableRow: View {
    let proc: ProcessWithCPU
    let maxRSS: UInt64
    let theme: MonitorTheme
    let showAnomalies: Bool
    let anomaly: Anomaly?
    let onKill: () -> Void

    @State private var hovered = false

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                if let anomaly {
                    Image(systemName: anomaly.kind.icon)
                        .font(.system(size: 11))
                        .foregroundStyle(anomaly.displayColor(theme: theme))
                }
                Text(proc.name)
                    .font(.system(size: 14, design: .rounded))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if showAnomalies {
                Text(anomaly?.displayName ?? "")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(anomaly.map { $0.displayColor(theme: theme) } ?? theme.textTertiary)
                    .frame(width: 80, alignment: .leading)
                    .lineLimit(1)
                Text(anomaly?.reason ?? "")
                    .font(.system(size: 11))
                    .foregroundStyle(theme.textSecondary)
                    .frame(width: 120, alignment: .leading)
                    .lineLimit(1)
            }

            Text(String(proc.pid))
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(theme.textSecondary)
                .frame(width: 56, alignment: .trailing)

            VStack(alignment: .trailing, spacing: 3) {
                Text(String(format: "%.1f", proc.cpuPercent))
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(theme.cpuColor(for: proc.cpuPercent))
                    .monospacedDigit()
                MiniProgressBar(
                    value: proc.cpuPercent,
                    maxValue: 100,
                    color: theme.cpuColor(for: proc.cpuPercent),
                    height: 3
                )
                .frame(width: 56)
            }
            .frame(width: 56)

            Text(proc.cpuTimeFormatted)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(theme.textSecondary)
                .frame(width: 72, alignment: .trailing)
                .lineLimit(1)

            Text(String(proc.threadCount))
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(theme.textSecondary)
                .monospacedDigit()
                .frame(width: 48, alignment: .trailing)

            VStack(alignment: .trailing, spacing: 3) {
                Text(proc.rssFormatted)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(theme.textSecondary)
                MiniProgressBar(
                    value: Double(proc.rss),
                    maxValue: Double(maxRSS),
                    color: theme.primary.opacity(0.8),
                    height: 3
                )
                .frame(width: 72)
            }
            .frame(width: 72, alignment: .trailing)

            if proc.pid > 100 {
                Button(action: onKill) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(theme.danger)
                }
                .buttonStyle(.plain)
                .opacity(hovered ? 1 : 0.45)
                .frame(width: 28)
            } else {
                Color.clear.frame(width: 28)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 48)
        .background(
            hovered ? theme.rowHover : Color.clear,
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
        .onHover { hovered = $0 }
    }
}
