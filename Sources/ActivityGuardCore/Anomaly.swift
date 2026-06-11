import Foundation

public enum AnomalyKind: String, Sendable, CaseIterable {
    case highCPU = "High CPU"
    case memoryLeak = "Memory Leak"
    case zombie = "Zombie"
    case highEnergy = "High Energy"

    public var icon: String {
        switch self {
        case .highCPU: return "flame.fill"
        case .memoryLeak: return "arrow.up.circle.fill"
        case .zombie: return "exclamationmark.circle.fill"
        case .highEnergy: return "bolt.fill"
        }
    }
}

public struct Anomaly: Identifiable, Sendable, Hashable {
    public var id: String { "\(kind.rawValue)-\(pid)" }
    public let kind: AnomalyKind
    public let pid: Int32
    public let processName: String
    public let reason: String
    public let value: Double
    public let memoryLeakSeverity: MemoryLeakSeverity?
    public let memoryGrowthBytes: UInt64?

    public init(
        kind: AnomalyKind,
        pid: Int32,
        processName: String,
        reason: String,
        value: Double,
        memoryLeakSeverity: MemoryLeakSeverity? = nil,
        memoryGrowthBytes: UInt64? = nil
    ) {
        self.kind = kind
        self.pid = pid
        self.processName = processName
        self.reason = reason
        self.value = value
        self.memoryLeakSeverity = memoryLeakSeverity
        self.memoryGrowthBytes = memoryGrowthBytes
    }
}
