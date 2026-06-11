import Foundation
import IOKit
import IOKit.ps

public struct SystemPower: Sendable {
    public enum ThermalLevel: String, Sendable {
        case nominal
        case fair
        case serious
        case critical

        public init(_ state: ProcessInfo.ThermalState) {
            switch state {
            case .nominal: self = .nominal
            case .fair: self = .fair
            case .serious: self = .serious
            case .critical: self = .critical
            @unknown default: self = .nominal
            }
        }
    }

    public let thermal: ThermalLevel
    public let batteryLevel: Double?
    public let isOnACPower: Bool
    public let powerSourceLabel: String

    public init(
        thermal: ThermalLevel,
        batteryLevel: Double?,
        isOnACPower: Bool,
        powerSourceLabel: String
    ) {
        self.thermal = thermal
        self.batteryLevel = batteryLevel
        self.isOnACPower = isOnACPower
        self.powerSourceLabel = powerSourceLabel
    }
}

public struct SystemPowerMonitor {
    public static func current() -> SystemPower {
        let thermal = SystemPower.ThermalLevel(ProcessInfo.processInfo.thermalState)
        let battery = readBatteryInfo()
        return SystemPower(
            thermal: thermal,
            batteryLevel: battery.level,
            isOnACPower: battery.onAC,
            powerSourceLabel: battery.sourceLabel
        )
    }

    private static func readBatteryInfo() -> (level: Double?, onAC: Bool, sourceLabel: String) {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [String],
              let source = sources.first,
              let info = IOPSGetPowerSourceDescription(snapshot, source as CFString)?.takeRetainedValue() as? [String: Any]
        else {
            return (nil, true, "AC")
        }

        let isAC = (info[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue
        let capacity = info[kIOPSCurrentCapacityKey] as? Int
        let label: String
        if isAC {
            label = "AC"
        } else if let capacity {
            label = "\(capacity)%"
        } else {
            label = "Battery"
        }

        return (
            isAC ? nil : Double(capacity ?? 0),
            isAC,
            label
        )
    }
}
