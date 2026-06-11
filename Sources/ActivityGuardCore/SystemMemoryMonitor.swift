import Foundation
import Darwin

public struct SystemMemory: Sendable {
    public let total: UInt64
    public let used: UInt64
    public let free: UInt64
    public let active: UInt64
    public let wired: UInt64
    public let compressed: UInt64

    public var usedPercent: Double {
        guard total > 0 else { return 0 }
        return Double(used) / Double(total) * 100
    }

    public var freePercent: Double {
        guard total > 0 else { return 0 }
        return Double(free) / Double(total) * 100
    }

    public init(
        total: UInt64,
        used: UInt64,
        free: UInt64,
        active: UInt64,
        wired: UInt64,
        compressed: UInt64
    ) {
        self.total = total
        self.used = used
        self.free = free
        self.active = active
        self.wired = wired
        self.compressed = compressed
    }
}

public struct SystemMemoryMonitor {
    public static func current() -> SystemMemory? {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size
        )
        let result = withUnsafeMutablePointer(to: &stats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, rebound, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }

        let pageSize = UInt64(vm_kernel_page_size)
        let free = UInt64(stats.free_count) * pageSize
        let active = UInt64(stats.active_count + stats.inactive_count) * pageSize
        let wired = UInt64(stats.wire_count) * pageSize
        let compressed = UInt64(stats.compressor_page_count) * pageSize
        let total = ProcessInfo.processInfo.physicalMemory
        let used = min(total, active + wired + compressed)

        return SystemMemory(
            total: total,
            used: used,
            free: free,
            active: active,
            wired: wired,
            compressed: compressed
        )
    }
}
