import AppKit
import SwiftUI
import Combine

@MainActor
final class StatusBarController: NSObject {
    static let shared = StatusBarController()

    private var statusItem: NSStatusItem?
    private var metricsPopover: NSPopover?
    private weak var viewModel: AppViewModel?
    private var clickCount = 0
    private var clickTimer: Timer?
    private var hostingController: NSHostingController<AnyView>?
    private var cancellables = Set<AnyCancellable>()

    private override init() {
        super.init()
    }

    func setup(viewModel: AppViewModel) {
        self.viewModel = viewModel

        if statusItem == nil {
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            statusItem = item

            if let button = item.button {
                button.target = self
                button.action = #selector(handleClick(_:))
                button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            }
        }

        updateLabel()
        observeViewModel()
    }

    private func observeViewModel() {
        cancellables.removeAll()
        guard let viewModel else { return }

        Publishers.MergeMany(
            viewModel.$systemCPU.map { _ in () }.eraseToAnyPublisher(),
            viewModel.$systemMemory.map { _ in () }.eraseToAnyPublisher(),
            viewModel.$systemGPU.map { _ in () }.eraseToAnyPublisher(),
            viewModel.$systemNetwork.map { _ in () }.eraseToAnyPublisher(),
            viewModel.$anomalies.map { _ in () }.eraseToAnyPublisher(),
            viewModel.objectWillChange.eraseToAnyPublisher()
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _ in self?.updateLabel() }
        .store(in: &cancellables)
    }

    private func updateLabel() {
        guard let button = statusItem?.button, let viewModel else { return }

        let hasAnomaly = !viewModel.anomalies.isEmpty
        let metric = viewModel.menuBarMetric
        let (text, iconName, isAlert) = menuBarContent(metric: metric, viewModel: viewModel, hasAnomaly: hasAnomaly)

        let attr = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium),
                .foregroundColor: isAlert ? NSColor.systemRed : NSColor.labelColor,
            ]
        )
        if let icon = NSImage(systemSymbolName: iconName, accessibilityDescription: nil) {
            icon.size = NSSize(width: 14, height: 14)
            let attachment = NSTextAttachment()
            attachment.image = icon
            attachment.bounds = CGRect(x: 0, y: -2, width: 14, height: 14)
            attr.append(NSAttributedString(attachment: attachment))
        }

        button.attributedTitle = attr
        button.toolTip = hasAnomaly
            ? L10n.tr("anomaly_tooltip", viewModel.language, viewModel.anomalies.count)
            : L10n.tr("metrics_tooltip", viewModel.language)
    }

    private func menuBarContent(
        metric: MenuBarMetric,
        viewModel: AppViewModel,
        hasAnomaly: Bool
    ) -> (text: String, icon: String, alert: Bool) {
        if hasAnomaly {
            return (" \(viewModel.anomalies.count) ", "exclamationmark.triangle.fill", true)
        }

        switch metric {
        case .cpu:
            let cpu = viewModel.systemCPU.total
            return (
                String(format: " %3.0f%% ", cpu),
                cpu > 80 ? "flame.fill" : "cpu",
                cpu > 80
            )
        case .memoryFree:
            let free = viewModel.formatMemoryBytes(viewModel.systemMemory.free)
            return (" \(free) ", "memorychip", viewModel.systemMemory.freePercent < 15)
        case .gpu:
            let gpu = viewModel.systemGPU.utilization
            return (
                String(format: " %3.0f%% ", gpu),
                "display",
                gpu > 80
            )
        case .network:
            let down = NetworkThroughput.formatRate(viewModel.systemNetwork.bytesInPerSec)
            let up = NetworkThroughput.formatRate(viewModel.systemNetwork.bytesOutPerSec)
            return (" \(down)↓\(up)↑ ", "network", false)
        }
    }

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            showContextMenu(on: sender)
            return
        }

        clickCount += 1
        clickTimer?.invalidate()
        clickTimer = Timer.scheduledTimer(withTimeInterval: 0.28, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if self.clickCount >= 2 {
                    self.closeMetricsPopover()
                    self.openMainPanel()
                } else {
                    self.toggleMetricsPopover(on: sender)
                }
                self.clickCount = 0
            }
        }
    }

    private func toggleMetricsPopover(on button: NSStatusBarButton) {
        if let popover = metricsPopover, popover.isShown {
            popover.performClose(nil)
            return
        }
        showMetricsPopover(on: button)
    }

    private func showMetricsPopover(on button: NSStatusBarButton) {
        guard let viewModel else { return }
        viewModel.loadOnDemand()

        let popover = metricsPopover ?? NSPopover()
        popover.behavior = .transient
        popover.animates = true

        let content = MetricsPopoverView(viewModel: viewModel) { [weak self] in
            self?.closeMetricsPopover()
            self?.openMainPanel()
        }

        hostingController = NSHostingController(rootView: AnyView(content))
        popover.contentViewController = hostingController
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        metricsPopover = popover
    }

    func closeMetricsPopover() {
        metricsPopover?.performClose(nil)
    }

    func openMainPanel() {
        closeMetricsPopover()
        guard let viewModel else { return }
        MainWindowController.shared.show(viewModel: viewModel)
    }

    private func showContextMenu(on button: NSStatusBarButton) {
        guard let viewModel else { return }
        let menu = NSMenu()

        let openItem = NSMenuItem(
            title: L10n.tr("open_panel", viewModel.language),
            action: #selector(openPanelFromMenu),
            keyEquivalent: ""
        )
        openItem.target = self
        menu.addItem(openItem)

        menu.addItem(.separator())

        let pauseTitle = viewModel.isMonitoring
            ? L10n.tr("pause", viewModel.language)
            : L10n.tr("resume", viewModel.language)
        let pauseItem = NSMenuItem(title: pauseTitle, action: #selector(toggleMonitoring), keyEquivalent: "")
        pauseItem.target = self
        menu.addItem(pauseItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: L10n.tr("quit", viewModel.language),
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
        button.performClick(nil)
        statusItem?.menu = nil
    }

    @objc private func openPanelFromMenu() {
        openMainPanel()
    }

    @objc private func toggleMonitoring() {
        guard let viewModel else { return }
        viewModel.isMonitoring ? viewModel.stopMonitoring() : viewModel.startMonitoring()
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
