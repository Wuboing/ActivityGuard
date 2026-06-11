import Foundation
import Darwin

public struct NetworkThroughput: Sendable {
    public let bytesInPerSec: Double
    public let bytesOutPerSec: Double
    public let totalBytesIn: UInt64
    public let totalBytesOut: UInt64

    public var totalPerSec: Double { bytesInPerSec + bytesOutPerSec }

    public init(bytesInPerSec: Double, bytesOutPerSec: Double, totalBytesIn: UInt64, totalBytesOut: UInt64) {
        self.bytesInPerSec = bytesInPerSec
        self.bytesOutPerSec = bytesOutPerSec
        self.totalBytesIn = totalBytesIn
        self.totalBytesOut = totalBytesOut
    }

    public static func formatRate(_ bytesPerSec: Double) -> String {
        let abs = Swift.abs(bytesPerSec)
        if abs >= 1_000_000_000 {
            return String(format: "%.1fG", bytesPerSec / 1_000_000_000)
        }
        if abs >= 1_000_000 {
            return String(format: "%.1fM", bytesPerSec / 1_000_000)
        }
        if abs >= 1_000 {
            return String(format: "%.0fK", bytesPerSec / 1_000)
        }
        return String(format: "%.0f", bytesPerSec)
    }
}

public struct SystemNetworkMonitor: Sendable {
    private static let lock = NSLock()
    private static var lastSample: (bytesIn: UInt64, bytesOut: UInt64, time: Date)?

    public static func sample() -> NetworkThroughput {
        let totals = interfaceByteTotals()
        let now = Date()

        lock.lock()
        defer { lock.unlock() }

        guard let prev = lastSample else {
            lastSample = (totals.inBytes, totals.outBytes, now)
            return NetworkThroughput(
                bytesInPerSec: 0,
                bytesOutPerSec: 0,
                totalBytesIn: totals.inBytes,
                totalBytesOut: totals.outBytes
            )
        }

        let dt = now.timeIntervalSince(prev.time)
        let inRate = dt > 0 ? Double(totals.inBytes &- prev.bytesIn) / dt : 0
        let outRate = dt > 0 ? Double(totals.outBytes &- prev.bytesOut) / dt : 0
        lastSample = (totals.inBytes, totals.outBytes, now)

        return NetworkThroughput(
            bytesInPerSec: max(0, inRate),
            bytesOutPerSec: max(0, outRate),
            totalBytesIn: totals.inBytes,
            totalBytesOut: totals.outBytes
        )
    }

    private static func interfaceByteTotals() -> (inBytes: UInt64, outBytes: UInt64) {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return (0, 0) }
        defer { freeifaddrs(ifaddr) }

        var bytesIn: UInt64 = 0
        var bytesOut: UInt64 = 0
        var ptr: UnsafeMutablePointer<ifaddrs>? = first

        while let current = ptr {
            let interface = current.pointee
            if interface.ifa_addr?.pointee.sa_family == UInt8(AF_LINK) {
                let name = String(cString: interface.ifa_name)
                if name == "lo0" { ptr = interface.ifa_next; continue }
                if let data = interface.ifa_data?.assumingMemoryBound(to: if_data.self) {
                    bytesIn += UInt64(data.pointee.ifi_ibytes)
                    bytesOut += UInt64(data.pointee.ifi_obytes)
                }
            }
            ptr = interface.ifa_next
        }

        return (bytesIn, bytesOut)
    }
}
