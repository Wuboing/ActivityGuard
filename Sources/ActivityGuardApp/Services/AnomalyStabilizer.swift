import Foundation
#if canImport(ActivityGuardCore)
import ActivityGuardCore
#endif

/// Suppresses brief anomaly flicker; surfaces only conditions that persist long enough.
@MainActor
final class AnomalyStabilizer {
    static let defaultPersistenceSeconds = 5
    static let minPersistenceSeconds = 0
    static let maxPersistenceSeconds = 120

    private var firstSeen: [String: Date] = [:]
    private var lastRaw: [Anomaly] = []

    func reset() {
        firstSeen.removeAll()
        lastRaw = []
    }

    func remove(pid: Int32) {
        let removedIDs = Set(lastRaw.filter { $0.pid == pid }.map(\.id))
        lastRaw.removeAll { $0.pid == pid }
        for id in removedIDs {
            firstSeen.removeValue(forKey: id)
        }
    }

    func updateRaw(_ raw: [Anomaly], at now: Date) {
        lastRaw = raw
        let currentIDs = Set(raw.map(\.id))

        for id in firstSeen.keys where !currentIDs.contains(id) {
            firstSeen.removeValue(forKey: id)
        }

        for anomaly in raw where firstSeen[anomaly.id] == nil {
            firstSeen[anomaly.id] = now
        }
    }

    func stabilized(persistenceSeconds: TimeInterval, at now: Date = Date()) -> [Anomaly] {
        guard persistenceSeconds > 0 else { return lastRaw }
        return lastRaw.filter { anomaly in
            guard let started = firstSeen[anomaly.id] else { return false }
            return now.timeIntervalSince(started) >= persistenceSeconds
        }
    }

    static func clampPersistenceSeconds(_ value: Int) -> Int {
        min(max(value, minPersistenceSeconds), maxPersistenceSeconds)
    }
}
