import SwiftUI

struct MenuBarPopover: View {
    @ObservedObject var viewModel: AppViewModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "cpu")
                Text(String(format: "CPU: %.1f%%", viewModel.systemCPU.total))
                    .font(.headline)
                Spacer()
                Button(L10n.tr("open", viewModel.language)) { openWindow(id: "main") }
            }

            Divider()

            if !viewModel.anomalies.isEmpty {
                ForEach(viewModel.anomalies.prefix(3)) { anomaly in
                    HStack {
                        Image(systemName: anomaly.kind.icon)
                            .foregroundStyle(anomaly.displayColor(theme: MonitorTheme(scheme: viewModel.colorScheme)))
                            .frame(width: 16)
                        Text(anomaly.processName).lineLimit(1)
                        Spacer()
                        Text(anomaly.reason)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption)
                }
                if viewModel.anomalies.count > 3 {
                    Text("+ \(viewModel.anomalies.count - 3) \(L10n.tr("more", viewModel.language))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Divider()
            }

            Text(L10n.tr("top_processes", viewModel.language))
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(viewModel.displayedProcesses.prefix(5)) { proc in
                HStack {
                    Text(proc.name)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(String(format: "%.1f%%", proc.cpuPercent))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(proc.cpuPercent > 50 ? .red : .primary)
                }
                .font(.caption)
            }

            Divider()

            HStack {
                Button(viewModel.isMonitoring
                    ? L10n.tr("pause", viewModel.language)
                    : L10n.tr("resume", viewModel.language)) {
                    viewModel.isMonitoring
                        ? viewModel.stopMonitoring()
                        : viewModel.startMonitoring()
                }
                .buttonStyle(.plain)
                .font(.caption)

                Spacer()

                Button(L10n.tr("quit", viewModel.language)) { NSApplication.shared.terminate(nil) }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding()
        .frame(width: 280)
    }
}
