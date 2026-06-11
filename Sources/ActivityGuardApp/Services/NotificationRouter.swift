import Foundation

@MainActor
final class NotificationRouter {
    static let shared = NotificationRouter()

    weak var viewModel: AppViewModel?

    private init() {}

    func handleNotificationTap(userInfo: [AnyHashable: Any]) {
        guard let viewModel else { return }

        MainWindowController.shared.show(viewModel: viewModel)

        let action = userInfo["action"] as? String

        if action == "openPanel" {
            // Thermal alert — just open dashboard.
            viewModel.backToDashboard()
            return
        }

        if let kindRaw = userInfo["kind"] as? String,
           let kind = AnomalyKind.allCases.first(where: { $0.rawValue == kindRaw }) {
            viewModel.openAnomalyProcesses(kind: kind)
        } else {
            viewModel.openAnomalyProcesses()
        }
    }
}
