import Foundation

struct CPUMetricProvider: MetricProvider {
    private var previousTicks: [CPUResult]?

    mutating func sample() -> CPUSnapshot {
        let result = collectCPUInfo(previousTicks: previousTicks)
        previousTicks = result.ticks
        return result.snapshot
    }
}

struct MemoryMetricProvider: MetricProvider {
    mutating func sample() -> MemorySnapshot {
        collectMemoryInfo()
    }
}

struct NetworkMetricProvider: MetricProvider {
    private var previousSample: NetworkSample?

    mutating func sample() -> NetworkSnapshot {
        let sample = collectNetworkInfo(previous: previousSample)
        previousSample = sample
        return NetworkSnapshot(
            downloadSpeed: sample.downloadSpeed,
            uploadSpeed: sample.uploadSpeed,
            smoothedDownloadSpeed: sample.downloadSpeed,
            smoothedUploadSpeed: sample.uploadSpeed,
            timestamp: sample.timestamp
        )
    }
}

struct ThermalMetricProvider: MetricProvider {
    private let refreshController: TemperatureRefreshController
    private var cachedBatteryTemperature: Double?

    init(
        temperatureProvider: BatteryTemperatureProviding = IOKitBatteryTemperatureProvider(),
        minimumInterval: TimeInterval = 15,
        currentTime: @escaping () -> TimeInterval = { Date().timeIntervalSince1970 }
    ) {
        self.refreshController = TemperatureRefreshController(
            minimumInterval: minimumInterval,
            currentTime: currentTime,
            fetchTemperature: { temperatureProvider.batteryTemperatureCelsius() }
        )
    }

    mutating func sample() -> ThermalSnapshot {
        if let batteryTemperature = refreshController.refreshIfNeeded() {
            cachedBatteryTemperature = batteryTemperature
        }

        return ThermalSnapshot(
            state: ProcessInfo.processInfo.thermalState,
            batteryTempCelsius: cachedBatteryTemperature,
            timestamp: Date()
        )
    }
}
