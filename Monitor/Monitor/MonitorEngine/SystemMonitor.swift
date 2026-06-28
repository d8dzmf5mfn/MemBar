import Foundation
import Combine

/// Posted after each refresh() cycle so MenuBarExtra views can force-update.
/// @Observable tracking is unreliable inside menu/popover contexts.
extension Notification.Name {
    static let systemMonitorDidRefresh = Notification.Name("systemMonitorDidRefresh")
}

@MainActor @Observable
final class SystemMonitor {
    // MARK: - Public snapshots
    // ---------------------------------------------------------------
    // Only fields that are actually read by views live here. Previously
    // we also exposed `selfSnapshot` / `lastUpdateTime` / `cpuHistory` /
    // `memoryHistory` — those have no consumers; the data was being
    // collected and stored every refresh but never read. Removed.
    // ---------------------------------------------------------------
    private(set) var cpu = CPUSnapshot(usagePercent: 0, perCoreUsage: [], systemPercent: 0, userPercent: 0, idlePercent: 0, timestamp: Date())
    private(set) var memory = MemorySnapshot(totalBytes: 0, usedBytes: 0, freeBytes: 0, wiredBytes: 0, compressedBytes: 0, purgeableBytes: 0, speculativeBytes: 0, appMemoryBytes: 0, usagePercent: 0, timestamp: Date())
    private(set) var network = NetworkSnapshot(downloadSpeed: 0, uploadSpeed: 0, smoothedDownloadSpeed: 0, smoothedUploadSpeed: 0, timestamp: Date())
    private(set) var thermal = ThermalSnapshot(state: .nominal, batteryTempCelsius: nil, timestamp: Date())

    // MARK: - Internal state
    private let preferences: PreferencesStore
    private let engine: MetricsEngine
    private var preferenceObserver: NSObjectProtocol?
    private var isStarted = false
    private var rawDownloadHistory: [Double] = []
    private var rawUploadHistory: [Double] = []
    private var smoothDownload: Double = 0
    private var smoothUpload: Double = 0
    private let smoothAlpha: Double = 0.4
    private var smoothDownloadHistory: [Double] = []
    private var smoothUploadHistory: [Double] = []

    // MARK: - Menu bar mode (user-persisted)
    enum MenuBarMode: String, CaseIterable {
        case memory = "memory"
        case network = "network"

        var label: String {
            switch self {
            case .memory: "内存使用"
            case .network: "网速"
            }
        }
    }

    var menuBarMode: MenuBarMode {
        get { preferences.menuBarMode }
        set { preferences.menuBarMode = newValue }
    }

    var useSmoothNetwork: Bool {
        get { preferences.useSmoothNetwork }
        set { preferences.useSmoothNetwork = newValue }
    }

    // MARK: - Convenience accessors
    var displayDownloadSpeed: Double {
        useSmoothNetwork ? network.smoothedDownloadSpeed : network.downloadSpeed
    }

    var displayUploadSpeed: Double {
        useSmoothNetwork ? network.smoothedUploadSpeed : network.uploadSpeed
    }

    var downloadHistoryData: [Double] { useSmoothNetwork ? smoothDownloadHistory : rawDownloadHistory }
    var uploadHistoryData: [Double]   { useSmoothNetwork ? smoothUploadHistory   : rawUploadHistory   }

    // MARK: - Tunables
    let maxHistoryCount = 60
    var refreshInterval: TimeInterval { preferences.refreshInterval }

    init(preferences: PreferencesStore = .shared, engine: MetricsEngine? = nil) {
        self.preferences = preferences
        self.engine = engine ?? MetricsEngine(preferences: preferences)
        observePreferenceChanges()
    }

    convenience init(temperatureProvider: BatteryTemperatureProviding) {
        var cpuProvider = CPUMetricProvider()
        var memoryProvider = MemoryMetricProvider()
        var networkProvider = NetworkMetricProvider()
        var thermalProvider = ThermalMetricProvider(temperatureProvider: temperatureProvider)
        let preferences = PreferencesStore.shared
        let engine = MetricsEngine(
            preferences: preferences,
            cpuProvider: AnyMetricProvider { cpuProvider.sample() },
            memoryProvider: AnyMetricProvider { memoryProvider.sample() },
            networkProvider: AnyMetricProvider { networkProvider.sample() },
            thermalProvider: AnyMetricProvider { thermalProvider.sample() }
        )
        self.init(preferences: preferences, engine: engine)
    }

    // MARK: - Lifecycle
    func start() {
        isStarted = true
        engine.start { [weak self] snapshot in
            self?.apply(snapshot)
        }
    }

    func stop() {
        isStarted = false
        engine.stop()
    }

    // MARK: - Refresh
    private func apply(_ snapshot: MetricsSnapshot) {
        cpu = snapshot.cpu
        memory = snapshot.memory

        smoothDownload = smoothAlpha * snapshot.network.downloadSpeed + (1 - smoothAlpha) * smoothDownload
        smoothUpload   = smoothAlpha * snapshot.network.uploadSpeed   + (1 - smoothAlpha) * smoothUpload

        network = NetworkSnapshot(
            downloadSpeed: snapshot.network.downloadSpeed,
            uploadSpeed: snapshot.network.uploadSpeed,
            smoothedDownloadSpeed: smoothDownload,
            smoothedUploadSpeed: smoothUpload,
            timestamp: snapshot.network.timestamp
        )

        thermal = snapshot.thermal

        // 5. History buffers (raw + smoothed, in KB/s — the menu bar
        //    format and popover bar chart both consume KB/s).
        appendHistory(&rawDownloadHistory, network.downloadSpeed / 1024.0)
        appendHistory(&rawUploadHistory,   network.uploadSpeed   / 1024.0)
        appendHistory(&smoothDownloadHistory, network.smoothedDownloadSpeed / 1024.0)
        appendHistory(&smoothUploadHistory,   network.smoothedUploadSpeed   / 1024.0)

        // 6. Force MenuBarExtra views to update (NSMenu/popover context
        //    freezes @Observable, so a notification is the reliable path).
        NotificationCenter.default.post(name: .systemMonitorDidRefresh, object: nil)
    }

    private func observePreferenceChanges() {
        preferenceObserver = NotificationCenter.default.addObserver(
            forName: .preferencesDidChange,
            object: preferences,
            queue: .main
        ) { [weak self] note in
            let key = note.userInfo?["key"] as? String
            Task { @MainActor [weak self] in
                guard let self else { return }
                if key == PreferencesStore.Keys.refreshInterval, self.isStarted {
                    self.start()
                } else {
                    NotificationCenter.default.post(name: .systemMonitorDidRefresh, object: nil)
                }
            }
        }
    }

    /// Append a sample to a rolling buffer, trimming to `maxHistoryCount`.
    private func appendHistory(_ buf: inout [Double], _ sample: Double) {
        buf.append(sample)
        if buf.count > maxHistoryCount { buf.removeFirst() }
    }

    // MARK: - User actions
    func toggleNetworkSmooth() {
        useSmoothNetwork.toggle()
    }
}
