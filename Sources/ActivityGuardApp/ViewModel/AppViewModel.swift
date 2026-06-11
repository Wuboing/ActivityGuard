import SwiftUI
import Combine

@MainActor
final class AppViewModel: ObservableObject {
    @Published var processes: [ProcessSnapshot] = []
    @Published var displayedProcesses: [ProcessWithCPU] = []
    @Published private(set) var filteredProcessesList: [ProcessWithCPU] = []
    @Published private(set) var anomaliesByPID: [Int32: Anomaly] = [:]
    @Published var systemCPU = SystemCPU(user: 0, system: 0, idle: 100)
    @Published var systemMemory = SystemMemory(total: 0, used: 0, free: 0, active: 0, wired: 0, compressed: 0)
    @Published var systemGPU = SystemGPU(utilization: 0)
    @Published var systemNetwork = NetworkThroughput(bytesInPerSec: 0, bytesOutPerSec: 0, totalBytesIn: 0, totalBytesOut: 0)
    @Published var systemPower = SystemPower(thermal: .nominal, batteryLevel: nil, isOnACPower: true, powerSourceLabel: "AC")
    @Published var anomalies: [Anomaly] = []
    @Published var selectedAnomalyKind: AnomalyKind? = nil
    @Published var showAnomaliesOnly = false
    @Published var searchText = ""
    @Published var processSortField: ProcessSortField = .cpu
    @Published var processSortAscending = false
    @Published var isMonitoring = false
    @Published var showingSettings = false
    @Published var showingDetail = false
    @Published private(set) var hasCompletedInitialLoad = false
    @Published var cpuHistory: [Double] = []
    @Published var memoryHistory: [Double] = []
    @Published var gpuHistory: [Double] = []
    @Published var networkHistory: [Double] = []
    @Published var toastMessage: String? = nil
    @Published var launchAtLoginEnabled = LaunchAtLoginManager.isEnabled
    @AppStorage("language") var language: AppLanguage = .english
    @AppStorage("colorScheme") var colorScheme: MonitorColorScheme = .dark
    @AppStorage("anomalyNotifications") var anomalyNotificationsEnabled = true
    @AppStorage("temperatureNotifications") var temperatureNotificationsEnabled = true
    @AppStorage("notificationIntervalSeconds") var notificationIntervalSeconds: Int = NotificationInterval.defaultValue.rawValue
    @AppStorage("memoryLeakWhitelist") var memoryLeakWhitelistText: String = MemoryLeakConfig.defaultWhitelistString
    @AppStorage("memoryLeakSevereGrowthMB") var memoryLeakSevereGrowthMB: Int = MemoryLeakConfig.defaultSevereGrowthThresholdMB
    @AppStorage("anomalyPersistenceSeconds") var anomalyPersistenceSeconds: Int = AnomalyStabilizer.defaultPersistenceSeconds
    @AppStorage("menuBarMetric") private var menuBarMetricRaw: String = MenuBarMetric.cpu.rawValue

    var menuBarMetric: MenuBarMetric {
        get { MenuBarMetric(rawValue: menuBarMetricRaw) ?? .cpu }
        set {
            menuBarMetricRaw = newValue.rawValue
            objectWillChange.send()
        }
    }

    var notificationInterval: NotificationInterval {
        get { NotificationInterval(rawValue: notificationIntervalSeconds) ?? .fiveMinutes }
        set { notificationIntervalSeconds = newValue.rawValue }
    }

    private var timer: Timer?
    private var persistenceTimer: Timer?
    private var filterCancellables = Set<AnyCancellable>()
    private let anomalyStabilizer = AnomalyStabilizer()
    private var previousSnapshots: [Int32: (cpuTime: UInt64, timestamp: Date)] = [:]
    private var lastSystemSampleTicks: SystemCPUTicks?
    private var lastSystemSampleTime: Date?
    private var lastProcessRefreshTime: Date?
    private var isRefreshing = false
    private let detector = AnomalyDetector()
    private let refreshInterval: TimeInterval = 10.0
    private let minCPUSampleInterval: TimeInterval = 1.0

    func toggleSort(_ field: ProcessSortField) {
        if processSortField == field {
            processSortAscending.toggle()
        } else {
            processSortField = field
            processSortAscending = field == .name
        }
    }

    private func sortProcesses(_ list: [ProcessWithCPU]) -> [ProcessWithCPU] {
        list.sorted { a, b in
            let ascending: Bool
            switch processSortField {
            case .cpu:
                ascending = a.cpuPercent < b.cpuPercent
            case .cpuTime:
                ascending = a.cpuTime < b.cpuTime
            case .threads:
                ascending = a.threadCount < b.threadCount
            case .memory:
                ascending = a.rss < b.rss
            case .pid:
                ascending = a.pid < b.pid
            case .name:
                ascending = a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            }
            return processSortAscending ? ascending : !ascending
        }
    }

    var anomalyCounts: [AnomalyKind: Int] {
        Dictionary(grouping: anomalies, by: \.kind).mapValues(\.count)
    }

    var topProcesses: [ProcessWithCPU] {
        Array(displayedProcesses.sorted { $0.cpuPercent > $1.cpuPercent }.prefix(8))
    }

    var theme: MonitorTheme { MonitorTheme(scheme: colorScheme) }

    var memoryLeakConfig: MemoryLeakConfig {
        MemoryLeakConfig(
            whitelistedProcessNames: MemoryLeakConfig.parseWhitelist(memoryLeakWhitelistText),
            severeGrowthThresholdMB: memoryLeakSevereGrowthMB
        )
    }

    init() {
        NotificationRouter.shared.viewModel = self
        bindFilterUpdates()
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            StatusBarController.shared.setup(viewModel: self)
            self.startMonitoring()
        }
    }

    private func bindFilterUpdates() {
        Publishers.CombineLatest4($displayedProcesses, $anomalies, $showAnomaliesOnly, $selectedAnomalyKind)
            .combineLatest($searchText.debounce(for: .milliseconds(120), scheduler: RunLoop.main))
            .combineLatest($processSortField, $processSortAscending)
            .sink { [weak self] _ in
                self?.updateFilteredProcesses()
            }
            .store(in: &filterCancellables)
    }

    func updateFilteredProcesses() {
        var result = displayedProcesses

        if showAnomaliesOnly {
            let anomalyPIDs = Set(anomalies.map(\.pid))
            result = result.filter { anomalyPIDs.contains($0.pid) }
        }

        if let kind = selectedAnomalyKind {
            let anomalyPIDs = Set(anomalies.filter { $0.kind == kind }.map(\.pid))
            result = result.filter { anomalyPIDs.contains($0.pid) }
        }

        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }

        filteredProcessesList = sortProcesses(result)
    }

    private func rebuildAnomalyLookup(_ items: [Anomaly]) {
        var lookup: [Int32: Anomaly] = [:]
        for anomaly in items where lookup[anomaly.pid] == nil {
            lookup[anomaly.pid] = anomaly
        }
        anomaliesByPID = lookup
    }

    func startMonitoring() {
        isMonitoring = true
        anomalyStabilizer.reset()
        lastSystemSampleTicks = CPUMonitor.getSystemCPUTicks()
        lastSystemSampleTime = Date()
        previousSnapshots = [:]

        if let memory = SystemMemoryMonitor.current() {
            systemMemory = memory
        }

        Task { await refreshAsync(updateCPU: false) }
        Task { await performInitialBootstrap() }

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in await self?.refreshAsync() }
        }

        persistenceTimer?.invalidate()
        persistenceTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.applyStabilizedAnomalies() }
        }
    }

    func stopMonitoring() {
        isMonitoring = false
        timer?.invalidate()
        timer = nil
        persistenceTimer?.invalidate()
        persistenceTimer = nil
    }

    /// Called when opening panel — refresh in background if data is stale.
    func loadOnDemand() {
        guard isMonitoring else { return }
        Task {
            await refreshIfStale()
            await ensureFreshCPU()
        }
    }

    func refreshNow() {
        guard isMonitoring else { return }
        Task { await ensureFreshCPU() }
    }

    func openAnomalyProcesses(kind: AnomalyKind? = nil) {
        showAnomaliesOnly = true
        selectedAnomalyKind = kind
        showingDetail = true
    }

    func openProcessList() {
        showAnomaliesOnly = false
        selectedAnomalyKind = nil
        showingDetail = true
    }

    func backToDashboard() {
        showAnomaliesOnly = false
        selectedAnomalyKind = nil
        showingDetail = false
    }

    func refreshIfStale(maxAge: TimeInterval = 5) async {
        let stale = lastProcessRefreshTime.map { Date().timeIntervalSince($0) > maxAge } ?? true
        guard stale else { return }
        await refreshAsync(updateCPU: false)
    }

    func refreshAsync(updateCPU: Bool = true) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        let now = Date()
        if updateCPU {
            updateSystemCPU(at: now)
        }

        let prevSnapshots = previousSnapshots
        let prevDisplayed = displayedProcesses

        let (snapshots, zombiePIDs, memory, gpu, network, power) = await Task.detached(priority: .userInitiated) {
            (
                ProcessMonitor.getAllProcesses(),
                ProcessMonitor.zombiePIDSet(),
                SystemMemoryMonitor.current(),
                SystemGPUMonitor.current(),
                SystemNetworkMonitor.sample(),
                SystemPowerMonitor.current()
            )
        }.value

        if let memory {
            systemMemory = memory
            appendHistory(&memoryHistory, memory.usedPercent)
        }
        systemGPU = gpu
        appendHistory(&gpuHistory, gpu.utilization)
        systemNetwork = network
        appendHistory(&networkHistory, network.totalPerSec / 1_000_000)
        systemPower = power

        var procsWithCPU: [ProcessWithCPU] = []
        procsWithCPU.reserveCapacity(snapshots.count)
        for snap in snapshots {
            let cpuPercent: Double
            if let prev = prevSnapshots[snap.pid] {
                let timeDelta = now.timeIntervalSince(prev.timestamp)
                if timeDelta >= minCPUSampleInterval {
                    let raw = Double(snap.cpuTime &- prev.cpuTime) / (timeDelta * 1_000_000_000) * 100
                    cpuPercent = min(raw, 100 * Double(CPUMonitor.processorCount))
                } else {
                    cpuPercent = prevDisplayed.first(where: { $0.pid == snap.pid })?.cpuPercent ?? 0
                }
            } else {
                cpuPercent = 0
            }
            procsWithCPU.append(ProcessWithCPU(
                pid: snap.pid,
                name: snap.name,
                cpuPercent: cpuPercent,
                cpuTime: snap.cpuTime,
                threadCount: snap.threadCount,
                rss: snap.rss
            ))
        }

        let rawAnomalies = detector.detect(
            snapshots: snapshots,
            systemCPU: systemCPU,
            zombiePIDs: zombiePIDs,
            memoryLeakConfig: memoryLeakConfig
        )

        processes = snapshots
        displayedProcesses = procsWithCPU
        anomalyStabilizer.updateRaw(rawAnomalies, at: now)
        applyStabilizedAnomalies(at: now)
        lastProcessRefreshTime = now

        AnomalyNotifier.shared.processThermal(
            level: power.thermal,
            language: language,
            enabled: temperatureNotificationsEnabled,
            intervalSeconds: notificationInterval.seconds
        )

        previousSnapshots = Dictionary(
            uniqueKeysWithValues: snapshots.map { ($0.pid, ($0.cpuTime, now)) }
        )
    }

    private func applyStabilizedAnomalies(at now: Date = Date()) {
        let persistence = TimeInterval(AnomalyStabilizer.clampPersistenceSeconds(anomalyPersistenceSeconds))
        let stabilized = anomalyStabilizer.stabilized(persistenceSeconds: persistence, at: now)
        let changed = stabilized != anomalies
        anomalies = stabilized
        rebuildAnomalyLookup(stabilized)

        guard changed else { return }
        AnomalyNotifier.shared.process(
            anomalies: stabilized,
            language: language,
            enabled: anomalyNotificationsEnabled,
            intervalSeconds: notificationInterval.seconds
        )
    }

    private func updateSystemCPU(at now: Date) {
        guard let prevTicks = lastSystemSampleTicks,
              let prevTime = lastSystemSampleTime,
              now.timeIntervalSince(prevTime) >= minCPUSampleInterval,
              let currentTicks = CPUMonitor.getSystemCPUTicks(),
              let cpu = SystemCPU.fromTicksDelta(prev: prevTicks, current: currentTicks) else {
            return
        }
        applySystemCPU(cpu)
        lastSystemSampleTicks = currentTicks
        lastSystemSampleTime = now
    }

    private func applySystemCPU(_ cpu: SystemCPU) {
        systemCPU = cpu
        appendHistory(&cpuHistory, cpu.total)
    }

    private func appendHistory(_ history: inout [Double], _ value: Double, limit: Int = 24) {
        history.append(value)
        if history.count > limit {
            history.removeFirst(history.count - limit)
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        if LaunchAtLoginManager.setEnabled(enabled) {
            launchAtLoginEnabled = LaunchAtLoginManager.isEnabled
        }
    }

    func refreshLaunchAtLoginStatus() {
        launchAtLoginEnabled = LaunchAtLoginManager.isEnabled
    }

    func formatMemoryBytes(_ bytes: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .memory)
    }

    private func performInitialBootstrap() async {
        guard let baseline = lastSystemSampleTicks else { return }
        try? await Task.sleep(nanoseconds: UInt64(minCPUSampleInterval * 1_000_000_000))
        guard isMonitoring else { return }
        await sampleCPU(from: baseline)
        await refreshAsync()
        hasCompletedInitialLoad = true
    }

    private func ensureFreshCPU() async {
        let isStale = lastSystemSampleTime.map { Date().timeIntervalSince($0) >= minCPUSampleInterval } ?? true
        guard isStale else { return }

        guard let baseline = CPUMonitor.getSystemCPUTicks() else { return }
        try? await Task.sleep(nanoseconds: UInt64(minCPUSampleInterval * 1_000_000_000))
        guard isMonitoring else { return }
        await sampleCPU(from: baseline)
        await refreshAsync()
    }

    private func sampleCPU(from baseline: SystemCPUTicks) async {
        guard let current = CPUMonitor.getSystemCPUTicks(),
              let cpu = SystemCPU.fromTicksDelta(prev: baseline, current: current) else {
            return
        }
        applySystemCPU(cpu)
        lastSystemSampleTicks = current
        lastSystemSampleTime = Date()
    }

    func killProcess(pid: Int32, processName: String) -> Bool {
        guard pid > 100 else { return false }
        let result = kill(pid, SIGTERM)
        if result != 0 {
            let forceResult = kill(pid, SIGKILL)
            if forceResult != 0 { return false }
        }
        anomalies.removeAll { $0.pid == pid }
        anomalyStabilizer.remove(pid: pid)
        displayedProcesses.removeAll { $0.pid == pid }
        toastMessage = L10n.tr("kill_success", language)
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if toastMessage == L10n.tr("kill_success", language) { toastMessage = nil }
        }
        return true
    }
}
