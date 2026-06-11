import Foundation

public enum MemoryLeakSeverity: String, Sendable {
    /// In-app warning only (orange).
    case moderate
    /// In-app alert (red) + system notification.
    case severe
}

public struct MemoryLeakConfig: Sendable {
    public static let defaultSevereGrowthThresholdMB = 300
    public static let minSevereGrowthThresholdMB = 100
    public static let maxSevereGrowthThresholdMB = 2048
    public static let severeGrowthThresholdStepMB = 50
    public static let severeRSSThreshold: UInt64 = 1024 * 1024 * 1024

    public static var severeGrowthThresholdRange: ClosedRange<Int> {
        minSevereGrowthThresholdMB...maxSevereGrowthThresholdMB
    }

    public static let defaultWhitelist: [String] = [
        "Google Chrome",
        "Chromium",
        "Chrome Helper",
        "Safari",
        "WebKit",
        "Xcode",
        "Code Helper",
        "node",
        "java",
        "Docker",
    ]

    public static var defaultWhitelistString: String {
        defaultWhitelist.joined(separator: ", ")
    }

    public let whitelistedProcessNames: [String]
    public let severeGrowthThreshold: UInt64

    public init(
        whitelistedProcessNames: [String] = defaultWhitelist,
        severeGrowthThresholdMB: Int = defaultSevereGrowthThresholdMB
    ) {
        self.whitelistedProcessNames = whitelistedProcessNames
        let clampedMB = Self.clampSevereGrowthThresholdMB(severeGrowthThresholdMB)
        self.severeGrowthThreshold = UInt64(clampedMB) * 1024 * 1024
    }

    public static func clampSevereGrowthThresholdMB(_ value: Int) -> Int {
        min(max(value, minSevereGrowthThresholdMB), maxSevereGrowthThresholdMB)
    }

    public func isWhitelisted(processName: String) -> Bool {
        let lower = processName.lowercased()
        return whitelistedProcessNames.contains { pattern in
            let trimmed = pattern.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return !trimmed.isEmpty && lower.contains(trimmed)
        }
    }

    public func severity(growth: UInt64, currentRSS: UInt64) -> MemoryLeakSeverity {
        if growth >= severeGrowthThreshold || currentRSS >= Self.severeRSSThreshold {
            return .severe
        }
        return .moderate
    }

    public static func parseWhitelist(_ text: String) -> [String] {
        text
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
