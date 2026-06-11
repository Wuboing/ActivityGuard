import AppKit
import SwiftUI

@MainActor
final class MainWindowController {
    static let shared = MainWindowController()

    private var window: NSWindow?
    private weak var viewModel: AppViewModel?

    private init() {}

    func show(viewModel: AppViewModel) {
        self.viewModel = viewModel

        if window == nil {
            let hosting = NSHostingController(
                rootView: ContentView(viewModel: viewModel)
                    .frame(minWidth: 920, minHeight: 500)
            )
            let w = NSWindow(contentViewController: hosting)
            w.title = "Activity Guard"
            w.setContentSize(NSSize(width: 960, height: 600))
            w.styleMask = [.titled, .closable, .resizable, .miniaturizable]
            w.center()
            w.isReleasedWhenClosed = false
            window = w
        }

        viewModel.loadOnDemand()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
