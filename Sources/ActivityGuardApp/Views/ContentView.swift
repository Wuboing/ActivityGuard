import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: AppViewModel

    private var theme: MonitorTheme { viewModel.theme }

    var body: some View {
        ZStack(alignment: .top) {
            Group {
                if viewModel.showingDetail {
                    ProcessDetailView(viewModel: viewModel)
                } else {
                    DashboardView(viewModel: viewModel)
                }
            }

            if let toast = viewModel.toastMessage {
                toastBanner(toast)
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .background(theme.windowMaterial)
        .toolbarBackground(.automatic, for: .windowToolbar)
        .toolbarColorScheme(theme.scheme == .dark ? .dark : .light, for: .windowToolbar)
        .toolbar {
            ToolbarItemGroup {
                if viewModel.showingDetail {
                    Button {
                        viewModel.backToDashboard()
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .help(L10n.tr("dashboard", viewModel.language))

                    if viewModel.showAnomaliesOnly {
                        Text(L10n.tr("anomaly_processes", viewModel.language))
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(theme.textSecondary)
                    }

                    Picker(L10n.tr("filter", viewModel.language), selection: $viewModel.selectedAnomalyKind) {
                        Text(L10n.tr("all", viewModel.language)).tag(nil as AnomalyKind?)
                        ForEach(AnomalyKind.allCases, id: \.self) { kind in
                            Label(kind.localizedName, systemImage: kind.icon).tag(kind as AnomalyKind?)
                        }
                    }
                    .pickerStyle(.menu)

                    TextField(L10n.tr("search", viewModel.language), text: $viewModel.searchText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 180)
                }

                Button { viewModel.refreshNow() } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help(L10n.tr("refresh", viewModel.language))

                HStack(spacing: 4) {
                    Image(systemName: "cpu")
                    Text(String(format: "%.1f%%", viewModel.systemCPU.total))
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(theme.cpuColor(for: viewModel.systemCPU.total))
                        .monospacedDigit()
                }

                Button {
                    viewModel.isMonitoring ? viewModel.stopMonitoring() : viewModel.startMonitoring()
                } label: {
                    Image(systemName: viewModel.isMonitoring ? "pause.circle" : "play.circle")
                }

                Button { viewModel.showingSettings = true } label: {
                    Image(systemName: "gearshape")
                }
            }
        }
        .sheet(isPresented: $viewModel.showingSettings) {
            SettingsView(viewModel: viewModel)
        }
        .onAppear { viewModel.loadOnDemand() }
    }

    private func toastBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(theme.success)
            Text(message)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(theme.textPrimary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: Capsule())
        .background(theme.success.opacity(0.14), in: Capsule())
        .overlay(Capsule().stroke(theme.success.opacity(0.35), lineWidth: 1))
        .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
        .padding(.top, 14)
    }
}

private struct ProcessDetailView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        ProcessTable(viewModel: viewModel)
    }
}
