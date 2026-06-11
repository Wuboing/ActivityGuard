import Foundation

enum MenuBarMetric: String, CaseIterable, Identifiable {
    case cpu
    case memoryFree
    case gpu
    case network

    var id: String { rawValue }

    func localizedName(_ language: AppLanguage) -> String {
        switch self {
        case .cpu: return L10n.tr("menu_bar_cpu", language)
        case .memoryFree: return L10n.tr("menu_bar_memory_free", language)
        case .gpu: return L10n.tr("menu_bar_gpu", language)
        case .network: return L10n.tr("menu_bar_network", language)
        }
    }
}
