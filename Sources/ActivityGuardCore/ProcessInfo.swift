import Foundation

public struct ProcessSnapshot: Identifiable, Sendable {
    public var id: Int32 { pid }
    public let pid: Int32
    public let name: String
    public let cpuTime: UInt64
    public let threadCount: Int32
    public let rss: UInt64

    public init(pid: Int32, name: String, cpuTime: UInt64, threadCount: Int32, rss: UInt64) {
        self.pid = pid
        self.name = name
        self.cpuTime = cpuTime
        self.threadCount = threadCount
        self.rss = rss
    }
}

public struct ProcessWithCPU: Identifiable, Sendable {
    public var id: Int32 { pid }
    public let pid: Int32
    public let name: String
    public let cpuPercent: Double
    public let cpuTime: UInt64
    public let threadCount: Int32
    public let rss: UInt64

    public var rssFormatted: String {
        ByteCountFormatter.string(fromByteCount: Int64(rss), countStyle: .memory)
    }

    public var cpuTimeFormatted: String {
        Self.formatCPUTime(cpuTime)
    }

    public init(
        pid: Int32,
        name: String,
        cpuPercent: Double,
        cpuTime: UInt64,
        threadCount: Int32,
        rss: UInt64
    ) {
        self.pid = pid
        self.name = name
        self.cpuPercent = cpuPercent
        self.cpuTime = cpuTime
        self.threadCount = threadCount
        self.rss = rss
    }

    private static func formatCPUTime(_ nanoseconds: UInt64) -> String {
        let seconds = Double(nanoseconds) / 1_000_000_000
        if seconds < 60 {
            return String(format: "%.2f", seconds)
        }
        let minutes = Int(seconds) / 60
        let remainder = seconds - Double(minutes * 60)
        return String(format: "%d:%05.2f", minutes, remainder)
    }
}

public struct SystemCPU: Sendable {
    public let user: Double
    public let system: Double
    public let idle: Double
    /// Matches Activity Monitor: 100% - idle%.
    public var total: Double { max(0, min(100, 100 - idle)) }

    public init(user: Double, system: Double, idle: Double) {
        self.user = user
        self.system = system
        self.idle = idle
    }

    public static func fromTicksDelta(prev: SystemCPUTicks, current: SystemCPUTicks) -> SystemCPU? {
        guard current.total > prev.total else { return nil }

        let deltaUser = current.user &- prev.user
        let deltaSystem = current.system &- prev.system
        let deltaIdle = current.idle &- prev.idle
        let deltaTotal = Double(deltaUser + deltaSystem + deltaIdle)
        guard deltaTotal > 0 else { return nil }

        let idlePercent = Double(deltaIdle) / deltaTotal * 100
        return SystemCPU(
            user: Double(deltaUser) / deltaTotal * 100,
            system: Double(deltaSystem) / deltaTotal * 100,
            idle: idlePercent
        )
    }
}

public struct SystemCPUTicks: Sendable {
    public let user: UInt64
    public let system: UInt64
    public let idle: UInt64

    public var total: UInt64 { user + system + idle }

    public init(user: UInt64, system: UInt64, idle: UInt64) {
        self.user = user
        self.system = system
        self.idle = idle
    }
}
