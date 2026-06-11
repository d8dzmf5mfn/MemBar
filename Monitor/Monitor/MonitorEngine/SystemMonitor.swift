import Foundation
import Combine

@MainActor @Observable
final class SystemMonitor {
    private(set) var cpu = CPUSnapshot(usagePercent: 0, perCoreUsage: [], systemPercent: 0, userPercent: 0, idlePercent: 0, timestamp: Date())
    private(set) var memory = MemorySnapshot(totalBytes: 0, usedBytes: 0, freeBytes: 0, wiredBytes: 0, compressedBytes: 0, purgeableBytes: 0, speculativeBytes: 0, appMemoryBytes: 0, usagePercent: 0, timestamp: Date())
    private(set) var network = NetworkSnapshot(downloadSpeed: 0, uploadSpeed: 0, smoothedDownloadSpeed: 0, smoothedUploadSpeed: 0, totalDownloaded: 0, totalUploaded: 0, timestamp: Date())
    private(set) var selfSnapshot = SelfSnapshot(memoryUsageMB: 0, cpuUsagePercent: 0, powerEstimateMW: 0, timestamp: Date())
    private(set) var thermal = ThermalSnapshot(state: .nominal, batteryTempCelsius: nil, timestamp: Date())
    private(set) var lastUpdateTime: Date = .distantPast

    private var timer: Timer?
    private var previousCPUTicks: [CPUResult]?
    private var previousNetworkSnapshot: NetworkSnapshot?
    private var previousSelfCPUTime: (total: UInt64, wall: UInt64)?
    private var cpuHistory: [Double] = []
    private var memoryHistory: [Double] = []
    private var rawDownloadHistory: [Double] = []
    private var rawUploadHistory: [Double] = []

    private var smoothDownload: Double = 0
    private var smoothUpload: Double = 0
    private let smoothAlpha: Double = 0.4
    private var smoothDownloadHistory: [Double] = []
    private var smoothUploadHistory: [Double] = []

    enum MenuBarMode: String, CaseIterable {
        case memory = "memory"
        case network = "network"

        var label: String {
            switch self {
            case .memory: "内存占用"
            case .network: "网速"
            }
        }
    }

    var menuBarMode: MenuBarMode {
        get { MenuBarMode(rawValue: UserDefaults.standard.string(forKey: "menuBarMode") ?? "") ?? .memory }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "menuBarMode") }
    }

    var useSmoothNetwork: Bool {
        get { UserDefaults.standard.bool(forKey: "useSmoothNetwork") }
        set { UserDefaults.standard.set(newValue, forKey: "useSmoothNetwork") }
    }

    var displayDownloadSpeed: Double {
        useSmoothNetwork ? network.smoothedDownloadSpeed : network.downloadSpeed
    }

    var displayUploadSpeed: Double {
        useSmoothNetwork ? network.smoothedUploadSpeed : network.uploadSpeed
    }

    var cpuHistoryData: [Double] { cpuHistory }
    var memoryHistoryData: [Double] { memoryHistory }
    var downloadHistoryData: [Double] { useSmoothNetwork ? smoothDownloadHistory : rawDownloadHistory }
    var uploadHistoryData: [Double] { useSmoothNetwork ? smoothUploadHistory : rawUploadHistory }

    let maxHistoryCount = 60
    let refreshInterval: TimeInterval = 2.0

    func start() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func refresh() {
        let cpuResult = collectCPUInfo(previousTicks: previousCPUTicks)
        cpu = cpuResult.snapshot
        previousCPUTicks = cpuResult.ticks

        memory = collectMemoryInfo()

        network = collectNetworkInfo(previous: previousNetworkSnapshot)
        previousNetworkSnapshot = network

        smoothDownload = smoothAlpha * network.downloadSpeed + (1 - smoothAlpha) * smoothDownload
        smoothUpload = smoothAlpha * network.uploadSpeed + (1 - smoothAlpha) * smoothUpload
        network = NetworkSnapshot(
            downloadSpeed: network.downloadSpeed,
            uploadSpeed: network.uploadSpeed,
            smoothedDownloadSpeed: smoothDownload,
            smoothedUploadSpeed: smoothUpload,
            totalDownloaded: network.totalDownloaded,
            totalUploaded: network.totalUploaded,
            timestamp: network.timestamp
        )

        let selfResult = collectSelfInfo(previousCPUTime: previousSelfCPUTime)
        selfSnapshot = selfResult.snapshot
        previousSelfCPUTime = selfResult.cpuTime

        // Update thermal state immediately (non-blocking)
        thermal = ThermalSnapshot(state: ProcessInfo.processInfo.thermalState, batteryTempCelsius: nil, timestamp: Date())
        // Fetch battery temperature in background (ioreg can be slow)
        let capturedSelf = self
        Task.detached(priority: .background) {
            let batteryTemp = collectBatteryTemperatureFromIOReg()
            await MainActor.run {
                capturedSelf.thermal = ThermalSnapshot(state: ProcessInfo.processInfo.thermalState, batteryTempCelsius: batteryTemp, timestamp: Date())
            }
        }

        lastUpdateTime = Date()

        cpuHistory.append(cpu.usagePercent)
        if cpuHistory.count > maxHistoryCount { cpuHistory.removeFirst() }

        memoryHistory.append(memory.usagePercent)
        if memoryHistory.count > maxHistoryCount { memoryHistory.removeFirst() }

        rawDownloadHistory.append(network.downloadSpeed / 1024.0)
        if rawDownloadHistory.count > maxHistoryCount { rawDownloadHistory.removeFirst() }

        rawUploadHistory.append(network.uploadSpeed / 1024.0)
        if rawUploadHistory.count > maxHistoryCount { rawUploadHistory.removeFirst() }

        smoothDownloadHistory.append(network.smoothedDownloadSpeed / 1024.0)
        if smoothDownloadHistory.count > maxHistoryCount { smoothDownloadHistory.removeFirst() }

        smoothUploadHistory.append(network.smoothedUploadSpeed / 1024.0)
        if smoothUploadHistory.count > maxHistoryCount { smoothUploadHistory.removeFirst() }
    }

    func toggleNetworkSmooth() {
        useSmoothNetwork.toggle()
    }
}
