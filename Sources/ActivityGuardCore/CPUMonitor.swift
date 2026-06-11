import Foundation
import Darwin

public struct CPUMonitor {
    public static var processorCount: Int {
        ProcessInfo.processInfo.processorCount
    }

    /// Per-CPU tick sum via host_processor_info (same source as Activity Monitor).
    public static func getSystemCPUTicks() -> SystemCPUTicks? {
        var cpuCount: natural_t = 0
        var cpuInfo: processor_info_array_t?
        var cpuInfoCount: mach_msg_type_number_t = 0

        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &cpuCount,
            &cpuInfo,
            &cpuInfoCount
        )

        guard result == KERN_SUCCESS, let info = cpuInfo, cpuCount > 0 else {
            return nil
        }

        var totalUser: UInt64 = 0
        var totalSystem: UInt64 = 0
        var totalIdle: UInt64 = 0

        for i in 0..<Int(cpuCount) {
            let offset = Int(CPU_STATE_MAX) * i
            totalUser += UInt64(info[offset + Int(CPU_STATE_USER)])
                + UInt64(info[offset + Int(CPU_STATE_NICE)])
            totalSystem += UInt64(info[offset + Int(CPU_STATE_SYSTEM)])
            totalIdle += UInt64(info[offset + Int(CPU_STATE_IDLE)])
        }

        let size = vm_size_t(cpuInfoCount) * vm_size_t(MemoryLayout<integer_t>.size)
        vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), size)

        return SystemCPUTicks(user: totalUser, system: totalSystem, idle: totalIdle)
    }
}
