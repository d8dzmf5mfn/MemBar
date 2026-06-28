import Foundation

@MainActor
final class MetricsEngine {
    typealias SnapshotHandler = (MetricsSnapshot) -> Void

    private let preferences: PreferencesStore
    private var cpuProvider: AnyMetricProvider<CPUSnapshot>
    private var memoryProvider: AnyMetricProvider<MemorySnapshot>
    private var networkProvider: AnyMetricProvider<NetworkSnapshot>
    private var thermalProvider: AnyMetricProvider<ThermalSnapshot>
    private var timer: Timer?
    private var onSnapshot: SnapshotHandler?

    private(set) var activeRefreshInterval: TimeInterval = 2.0

    var isRunning: Bool { timer != nil }

    convenience init(preferences: PreferencesStore = .shared) {
        var cpuProvider = CPUMetricProvider()
        var memoryProvider = MemoryMetricProvider()
        var networkProvider = NetworkMetricProvider()
        var thermalProvider = ThermalMetricProvider()
        self.init(
            preferences: preferences,
            cpuProvider: AnyMetricProvider {
                cpuProvider.sample()
            },
            memoryProvider: AnyMetricProvider {
                memoryProvider.sample()
            },
            networkProvider: AnyMetricProvider {
                networkProvider.sample()
            },
            thermalProvider: AnyMetricProvider {
                thermalProvider.sample()
            }
        )
    }

    init(
        preferences: PreferencesStore,
        cpuProvider: AnyMetricProvider<CPUSnapshot>,
        memoryProvider: AnyMetricProvider<MemorySnapshot>,
        networkProvider: AnyMetricProvider<NetworkSnapshot>,
        thermalProvider: AnyMetricProvider<ThermalSnapshot>
    ) {
        self.preferences = preferences
        self.cpuProvider = cpuProvider
        self.memoryProvider = memoryProvider
        self.networkProvider = networkProvider
        self.thermalProvider = thermalProvider
    }

    func start(_ onSnapshot: @escaping SnapshotHandler) {
        stop()
        self.onSnapshot = onSnapshot
        activeRefreshInterval = preferences.refreshInterval
        refreshNow(onSnapshot)
        timer = Timer.scheduledTimer(withTimeInterval: activeRefreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let onSnapshot = self.onSnapshot else { return }
                self.refreshNow(onSnapshot)
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        onSnapshot = nil
    }

    func refreshNow(_ onSnapshot: SnapshotHandler) {
        onSnapshot(
            MetricsSnapshot(
                cpu: cpuProvider.sample(),
                memory: memoryProvider.sample(),
                network: networkProvider.sample(),
                thermal: thermalProvider.sample()
            )
        )
    }
}
