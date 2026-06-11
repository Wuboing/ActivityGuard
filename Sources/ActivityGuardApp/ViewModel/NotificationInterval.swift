import Foundation

enum NotificationInterval: Int, CaseIterable, Identifiable, Sendable {
    case fifteenSeconds = 15
    case thirtySeconds = 30
    case oneMinute = 60
    case fiveMinutes = 300
    case tenMinutes = 600
    case thirtyMinutes = 1800
    case oneHour = 3600

    var id: Int { rawValue }

    var seconds: TimeInterval { TimeInterval(rawValue) }

    func localizedLabel(_ language: AppLanguage) -> String {
        let zh = language == .chinese
        switch self {
        case .fifteenSeconds: return zh ? "15 秒" : "15 sec"
        case .thirtySeconds: return zh ? "30 秒" : "30 sec"
        case .oneMinute: return zh ? "1 分钟" : "1 min"
        case .fiveMinutes: return zh ? "5 分钟" : "5 min"
        case .tenMinutes: return zh ? "10 分钟" : "10 min"
        case .thirtyMinutes: return zh ? "30 分钟" : "30 min"
        case .oneHour: return zh ? "1 小时" : "1 hour"
        }
    }

    static var defaultValue: NotificationInterval { .fiveMinutes }
}
