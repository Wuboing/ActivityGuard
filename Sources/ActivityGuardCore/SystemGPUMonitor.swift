import Foundation
import IOKit

public struct SystemGPU: Sendable {
    public let utilization: Double

    public init(utilization: Double) {
        self.utilization = max(0, min(100, utilization))
    }
}

public struct SystemGPUMonitor {
    public static func current() -> SystemGPU {
        SystemGPU(utilization: readUtilization())
    }

    private static func readUtilization() -> Double {
        for matching in ["IOAccelerator", "AGXAccelerator", "AMDAccelerator"] {
            if let value = utilizationFromService(matching: matching) {
                return value
            }
        }
        return 0
    }

    private static func utilizationFromService(matching: String) -> Double? {
        var iterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(
            kIOMainPortDefault,
            IOServiceMatching(matching),
            &iterator
        )
        guard result == KERN_SUCCESS else { return nil }
        defer { IOObjectRelease(iterator) }

        var service = IOIteratorNext(iterator)
        while service != 0 {
            defer {
                IOObjectRelease(service)
                service = IOIteratorNext(iterator)
            }

            if let util = performanceUtilization(service: service) {
                return util
            }
        }
        return nil
    }

    private static func performanceUtilization(service: io_service_t) -> Double? {
        guard let property = IORegistryEntryCreateCFProperty(
            service,
            "PerformanceStatistics" as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() as? [String: Any] else {
            return nil
        }

        if let value = property["Device Utilization %"] as? Int {
            return Double(value)
        }
        if let value = property["Device Utilization %"] as? Double {
            return value
        }
        if let value = property["GPU Activity(%)"] as? Int {
            return Double(value)
        }
        return nil
    }
}
