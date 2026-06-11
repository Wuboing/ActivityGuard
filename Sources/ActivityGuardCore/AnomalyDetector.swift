import Foundation

public struct ProcessHistorySnapshot: Sendable {
    public let cpuTime: UInt64
    public let rss: UInt64
    public let timestamp: Date

    public init(cpuTime: UInt64, rss: UInt64, timestamp: Date) {
        self.cpuTime = cpuTime
        self.rss = rss
        self.timestamp = timestamp
    }
}

/// Detection thresholds — tuned to reduce false positives.
public struct AnomalyThresholds: Sendable {
    public var highCPUPercent: Double = 95
    public var highCPUSamples: Int = 2
    public var sustainedCPUPercent: Double = 85
    public var sustainedCPUSamples: Int = 4
    public var memoryLeakMinRSS: UInt64 = 50 * 1024 * 1024
    public var memoryLeakGrowthFactor: Double = 2.0
    public var memoryLeakMinGrowth: UInt64 = 100 * 1024 * 1024
    public var memoryLeakSamples: Int = 5

    public init() {}
}

@MainActor
public class AnomalyDetector {
    private var processHistory: [Int32: [ProcessHistorySnapshot]] = [:]
    private let maxSamples = 6
    private let thresholds: AnomalyThresholds

    public init(thresholds: AnomalyThresholds = AnomalyThresholds()) {
        self.thresholds = thresholds
    }

    public func detect(
        snapshots: [ProcessSnapshot],
        systemCPU: SystemCPU,
        zombiePIDs: Set<pid_t> = []
    ) -> [Anomaly] {
        let now = Date()
        var anomalies: [Anomaly] = []
        let zombies = zombiePIDs.isEmpty ? ProcessMonitor.zombiePIDSet() : zombiePIDs

        for snap in snapshots {
            if zombies.contains(snap.pid) {
                anomalies.append(Anomaly(
                    kind: .zombie,
                    pid: snap.pid,
                    processName: snap.name,
                    reason: "Defunct process (zombie)",
                    value: 0
                ))
                continue
            }

            var history = processHistory[snap.pid] ?? []
            history.append(ProcessHistorySnapshot(cpuTime: snap.cpuTime, rss: snap.rss, timestamp: now))
            if history.count > maxSamples { history.removeFirst() }
            processHistory[snap.pid] = history

            guard history.count >= 2 else { continue }

            let prev = history[history.count - 2]
            let curr = history.last!
            let timeDelta = curr.timestamp.timeIntervalSince(prev.timestamp)
            guard timeDelta > 0 else { continue }

            let cpuDelta = curr.cpuTime &- prev.cpuTime
            let cpuPercent = Double(cpuDelta) / (timeDelta * 1_000_000_000) * 100

            if cpuPercent > thresholds.highCPUPercent && countHighCPU(history: history) >= thresholds.highCPUSamples {
                anomalies.append(Anomaly(
                    kind: .highCPU, pid: snap.pid, processName: snap.name,
                    reason: String(format: "CPU: %.1f%%", cpuPercent), value: cpuPercent
                ))
            }

            if history.count >= thresholds.sustainedCPUSamples,
               sustainedHighCPU(history: history, threshold: thresholds.sustainedCPUPercent, samples: thresholds.sustainedCPUSamples) {
                anomalies.append(Anomaly(
                    kind: .highEnergy, pid: snap.pid, processName: snap.name,
                    reason: String(format: "Sustained CPU ≥ %.0f%%", thresholds.sustainedCPUPercent),
                    value: cpuPercent
                ))
            }

            if history.count >= thresholds.memoryLeakSamples {
                let firstRSS = history.first!.rss
                let lastRSS = curr.rss
                let growth = lastRSS > firstRSS ? lastRSS - firstRSS : 0
                if firstRSS >= thresholds.memoryLeakMinRSS,
                   Double(lastRSS) >= Double(firstRSS) * thresholds.memoryLeakGrowthFactor,
                   growth >= thresholds.memoryLeakMinGrowth {
                    anomalies.append(Anomaly(
                        kind: .memoryLeak, pid: snap.pid, processName: snap.name,
                        reason: String(
                            format: "RSS: %@ → %@",
                            ByteCountFormatter.string(fromByteCount: Int64(firstRSS), countStyle: .memory),
                            ByteCountFormatter.string(fromByteCount: Int64(lastRSS), countStyle: .memory)
                        ),
                        value: Double(lastRSS)
                    ))
                }
            }
        }

        let currentPIDs = Set(snapshots.map(\.pid))
        for pid in processHistory.keys where !currentPIDs.contains(pid) {
            processHistory.removeValue(forKey: pid)
        }

        return dedupe(anomalies)
    }

    private func dedupe(_ anomalies: [Anomaly]) -> [Anomaly] {
        var best: [String: Anomaly] = [:]
        for a in anomalies {
            best[a.id] = a
        }
        return Array(best.values)
    }

    private func countHighCPU(history: [ProcessHistorySnapshot]) -> Int {
        guard history.count >= 2 else { return 0 }
        var count = 0
        for i in 1..<history.count {
            let prev = history[i - 1]
            let curr = history[i]
            let dt = curr.timestamp.timeIntervalSince(prev.timestamp)
            guard dt > 0 else { continue }
            let cpu = Double(curr.cpuTime &- prev.cpuTime) / (dt * 1_000_000_000) * 100
            if cpu > thresholds.highCPUPercent { count += 1 }
        }
        return count
    }

    private func sustainedHighCPU(history: [ProcessHistorySnapshot], threshold: Double, samples: Int) -> Bool {
        guard history.count >= samples else { return false }
        let recent = history.suffix(samples)
        var highs = 0
        let arr = Array(recent)
        for i in 1..<arr.count {
            let dt = arr[i].timestamp.timeIntervalSince(arr[i - 1].timestamp)
            guard dt > 0 else { continue }
            let cpu = Double(arr[i].cpuTime &- arr[i - 1].cpuTime) / (dt * 1_000_000_000) * 100
            if cpu >= threshold { highs += 1 }
        }
        return highs >= samples - 1
    }
}
