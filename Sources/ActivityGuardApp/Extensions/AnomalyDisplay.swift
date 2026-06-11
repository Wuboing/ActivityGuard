import SwiftUI
#if canImport(ActivityGuardCore)
import ActivityGuardCore
#endif

extension Anomaly {
    var displayName: String {
        if kind == .memoryLeak, memoryLeakSeverity == .severe {
            let lang = AppLanguage(rawValue: UserDefaults.standard.string(forKey: "language") ?? "en") ?? .english
            return L10n.tr("memory_leak_severe", lang)
        }
        return kind.localizedName
    }

    func displayColor(theme: MonitorTheme) -> Color {
        switch kind {
        case .memoryLeak:
            return memoryLeakSeverity == .severe ? theme.danger : theme.warning
        case .highCPU:
            return theme.danger
        case .zombie:
            return theme.textTertiary
        case .highEnergy:
            return theme.warning
        }
    }
}
