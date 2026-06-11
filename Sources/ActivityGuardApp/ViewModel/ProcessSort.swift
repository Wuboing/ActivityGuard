import Foundation

enum ProcessSortField: String, CaseIterable, Sendable {
    case cpu
    case cpuTime
    case threads
    case memory
    case pid
    case name
}
