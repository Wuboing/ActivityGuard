import Foundation
import Darwin

public struct ProcessMonitor {
    public static func getAllProcesses() -> [ProcessSnapshot] {
        let pidCount = proc_listallpids(nil, 0)
        guard pidCount > 0 else { return [] }

        let bufferSize = Int(pidCount) * MemoryLayout<pid_t>.size
        let pidList = UnsafeMutablePointer<pid_t>.allocate(capacity: Int(pidCount))
        defer { pidList.deallocate() }

        let actualCount = proc_listallpids(pidList, Int32(bufferSize))
        guard actualCount > 0 else { return [] }

        var processes: [ProcessSnapshot] = []
        processes.reserveCapacity(Int(actualCount))

        for i in 0..<Int(actualCount) {
            let pid = pidList[i]
            if pid == 0 { continue }

            var taskInfo = proc_taskinfo()
            let infoSize = MemoryLayout<proc_taskinfo>.size
            let ret = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &taskInfo, Int32(infoSize))
            guard ret >= infoSize else { continue }

            let nameBuffer = UnsafeMutablePointer<CChar>.allocate(capacity: 64)
            defer { nameBuffer.deallocate() }
            proc_name(pid, nameBuffer, 64)
            let name = String(cString: nameBuffer)
            if name.isEmpty { continue }

            processes.append(ProcessSnapshot(
                pid: pid,
                name: name,
                cpuTime: taskInfo.pti_total_user + taskInfo.pti_total_system,
                threadCount: taskInfo.pti_threadnum,
                rss: taskInfo.pti_resident_size
            ))
        }

        return processes
    }

    /// All PIDs in SZOMB state — one sysctl instead of per-process lookups.
    public static func zombiePIDSet() -> Set<pid_t> {
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0]
        var size = 0
        guard sysctl(&mib, 4, nil, &size, nil, 0) == 0, size > 0 else { return [] }

        let buffer = UnsafeMutablePointer<kinfo_proc>.allocate(capacity: size)
        defer { buffer.deallocate() }

        guard sysctl(&mib, 4, buffer, &size, nil, 0) == 0 else { return [] }

        let count = size / MemoryLayout<kinfo_proc>.stride
        var zombies = Set<pid_t>()
        zombies.reserveCapacity(8)
        for i in 0..<count where buffer[i].kp_proc.p_stat == SZOMB {
            zombies.insert(buffer[i].kp_proc.p_pid)
        }
        return zombies
    }
}
