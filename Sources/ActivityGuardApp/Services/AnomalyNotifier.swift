import Foundation
import UserNotifications

enum NotificationPermissionStatus: Sendable {
    case authorized
    case denied
    case notDetermined
}

@MainActor
final class AnomalyNotifier {
    static let shared = AnomalyNotifier()

    /// Kinds that trigger system notifications. Memory leaks notify only when severe.
    static let notifiableKinds: Set<AnomalyKind> = [.zombie, .memoryLeak]

    private static func shouldNotify(_ anomaly: Anomaly) -> Bool {
        switch anomaly.kind {
        case .zombie:
            return true
        case .memoryLeak:
            return anomaly.memoryLeakSeverity == .severe
        default:
            return false
        }
    }

    private var knownAnomalyIDs: Set<String> = []
    /// Tracks severe memory leaks already notified (supports moderate → severe escalation).
    private var notifiedSevereMemoryLeakIDs: Set<String> = []
    private var permissionRequested = false
    private var hasInitialized = false
    private var lastNotificationTime: Date?
    private var pendingAnomalies: [Anomaly] = []

    // Thermal alert tracking
    private var lastNotifiedThermal: SystemPower.ThermalLevel?
    private var lastThermalNotificationTime: Date?
    private var hasInitializedThermal = false

    private var canUseNotifications: Bool {
        Bundle.main.bundleIdentifier != nil
    }

    private init() {}

    func requestPermissionIfNeeded() {
        guard canUseNotifications, !permissionRequested else { return }
        permissionRequested = true
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    func currentPermissionStatus() async -> NotificationPermissionStatus {
        guard canUseNotifications else { return .denied }
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return .authorized
        case .denied:
            return .denied
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .denied
        }
    }

    func ensureAuthorization() async -> Bool {
        guard canUseNotifications else { return false }
        let status = await currentPermissionStatus()
        switch status {
        case .authorized:
            return true
        case .notDetermined:
            permissionRequested = true
            return await withCheckedContinuation { continuation in
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    continuation.resume(returning: granted)
                }
            }
        case .denied:
            return false
        }
    }

    @discardableResult
    func sendTestNotification(language: AppLanguage) async -> Bool {
        guard await ensureAuthorization() else { return false }

        let content = UNMutableNotificationContent()
        content.title = L10n.tr("test_notification_title", language)
        content.subtitle = "Activity Guard"
        content.body = L10n.tr("test_notification_body", language)
        content.sound = .default
        content.userInfo = ["action": "openAnomalies"]

        let request = UNNotificationRequest(
            identifier: "test-notification-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )

        return await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().add(request) { error in
                continuation.resume(returning: error == nil)
            }
        }
    }

    func process(
        anomalies: [Anomaly],
        language: AppLanguage,
        enabled: Bool,
        intervalSeconds: TimeInterval
    ) {
        let notifiable = anomalies.filter { Self.shouldNotify($0) }

        guard enabled else {
            knownAnomalyIDs = Set(notifiable.map(\.id))
            notifiedSevereMemoryLeakIDs = notifiedSevereMemoryLeakIDs.intersection(knownAnomalyIDs)
            pendingAnomalies = []
            return
        }

        let currentIDs = Set(notifiable.map(\.id))
        notifiedSevereMemoryLeakIDs.formIntersection(currentIDs)

        guard hasInitialized else {
            knownAnomalyIDs = currentIDs
            notifiedSevereMemoryLeakIDs = Set(
                notifiable.filter { $0.kind == .memoryLeak && $0.memoryLeakSeverity == .severe }.map(\.id)
            )
            hasInitialized = true
            return
        }

        guard canUseNotifications else { return }

        let newAnomalies = notifiable.filter { anomaly in
            if anomaly.kind == .memoryLeak, anomaly.memoryLeakSeverity == .severe {
                return !notifiedSevereMemoryLeakIDs.contains(anomaly.id)
            }
            return !knownAnomalyIDs.contains(anomaly.id)
        }
        knownAnomalyIDs = currentIDs
        for anomaly in notifiable where anomaly.kind == .memoryLeak && anomaly.memoryLeakSeverity == .severe {
            notifiedSevereMemoryLeakIDs.insert(anomaly.id)
        }

        if !newAnomalies.isEmpty {
            mergePending(newAnomalies)
        }

        guard !pendingAnomalies.isEmpty else { return }

        let now = Date()
        if let last = lastNotificationTime, now.timeIntervalSince(last) < intervalSeconds {
            return
        }

        flushPending(language: language)
    }

    private func mergePending(_ newOnes: [Anomaly]) {
        var byID: [String: Anomaly] = Dictionary(uniqueKeysWithValues: pendingAnomalies.map { ($0.id, $0) })
        for anomaly in newOnes {
            byID[anomaly.id] = anomaly
        }
        pendingAnomalies = Array(byID.values)
    }

    private func flushPending(language: AppLanguage) {
        guard !pendingAnomalies.isEmpty else { return }

        if pendingAnomalies.count == 1, let anomaly = pendingAnomalies.first {
            sendNotification(for: anomaly, language: language)
        } else {
            sendSummaryNotification(anomalies: pendingAnomalies, language: language)
        }

        lastNotificationTime = Date()
        pendingAnomalies = []
    }

    private func notificationUserInfo(for anomalies: [Anomaly]) -> [String: Any] {
        if anomalies.count == 1, let a = anomalies.first {
            return ["action": "openAnomalies", "kind": a.kind.rawValue, "pid": a.pid]
        }
        return ["action": "openAnomalies", "kind": AnomalyKind.zombie.rawValue]
    }

    private func sendSummaryNotification(anomalies: [Anomaly], language: AppLanguage) {
        let content = UNMutableNotificationContent()
        content.title = L10n.tr("anomaly_notification_title", language)
        content.subtitle = L10n.tr("anomaly_summary_subtitle", language, anomalies.count)
        let preview = anomalies.prefix(3).map { "\($0.processName) (\($0.displayName))" }.joined(separator: ", ")
        let suffix = anomalies.count > 3 ? L10n.tr("anomaly_summary_more", language, anomalies.count - 3) : ""
        content.body = preview + suffix
        content.sound = .default
        content.userInfo = notificationUserInfo(for: anomalies)

        let request = UNNotificationRequest(
            identifier: "anomaly-batch-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Thermal alerts

    /// Edge-triggered: fires once when thermal state rises into serious/critical (or escalates further),
    /// throttled by `intervalSeconds`. Does not fire when cooling back down.
    func processThermal(
        level: SystemPower.ThermalLevel,
        language: AppLanguage,
        enabled: Bool,
        intervalSeconds: TimeInterval
    ) {
        guard enabled else {
            lastNotifiedThermal = level
            return
        }

        guard hasInitializedThermal else {
            lastNotifiedThermal = level
            hasInitializedThermal = true
            return
        }

        guard canUseNotifications else { return }

        let isHot = (level == .serious || level == .critical)
        guard isHot else {
            // Reset when system cools so a future rise can re-fire.
            lastNotifiedThermal = level
            return
        }

        let escalated: Bool
        switch (lastNotifiedThermal, level) {
        case (.none, _): escalated = true
        case (.some(.nominal), _), (.some(.fair), _): escalated = true
        case (.some(.serious), .critical): escalated = true
        default: escalated = false
        }

        guard escalated else { return }

        let now = Date()
        if let last = lastThermalNotificationTime, now.timeIntervalSince(last) < intervalSeconds {
            return
        }

        sendThermalNotification(level: level, language: language)
        lastNotifiedThermal = level
        lastThermalNotificationTime = now
    }

    private func sendThermalNotification(level: SystemPower.ThermalLevel, language: AppLanguage) {
        let content = UNMutableNotificationContent()
        content.title = L10n.tr("temperature_notification_title", language)
        content.subtitle = thermalLocalizedName(level, language)
        content.body = L10n.tr(
            level == .critical ? "temperature_notification_body_critical" : "temperature_notification_body_serious",
            language
        )
        content.sound = .default
        content.userInfo = ["action": "openPanel", "thermal": level.rawValue]

        let request = UNNotificationRequest(
            identifier: "thermal-\(level.rawValue)-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func thermalLocalizedName(_ level: SystemPower.ThermalLevel, _ lang: AppLanguage) -> String {
        switch level {
        case .nominal: return L10n.tr("thermal_nominal", lang)
        case .fair: return L10n.tr("thermal_fair", lang)
        case .serious: return L10n.tr("thermal_serious", lang)
        case .critical: return L10n.tr("thermal_critical", lang)
        }
    }

    private func sendNotification(for anomaly: Anomaly, language: AppLanguage) {
        guard canUseNotifications else { return }

        let content = UNMutableNotificationContent()
        if anomaly.kind == .memoryLeak, anomaly.memoryLeakSeverity == .severe {
            content.title = L10n.tr("memory_leak_severe_notification_title", language)
            content.subtitle = anomaly.processName
            if let growth = anomaly.memoryGrowthBytes {
                let growthText = ByteCountFormatter.string(fromByteCount: Int64(growth), countStyle: .memory)
                content.body = L10n.tr("memory_leak_severe_notification_body", language, growthText, anomaly.reason)
            } else {
                content.body = anomaly.reason
            }
        } else {
            content.title = L10n.tr("anomaly_notification_title", language)
            content.subtitle = anomaly.processName
            content.body = "\(anomaly.kind.localizedName): \(anomaly.reason)"
        }
        content.sound = .default
        content.userInfo = notificationUserInfo(for: [anomaly])

        let request = UNNotificationRequest(
            identifier: "anomaly-\(anomaly.id)-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
