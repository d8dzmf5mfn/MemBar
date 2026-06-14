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
    private var timer: Timer?
    private var previousCPUTicks: [CPUResult]?
    private var previousNetworkSample: NetworkSample?

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
    let refreshInterval: TimeInterval = 2.0

    // MARK: - Lifecycle
    func start() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refresh()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Refresh
    private func refresh() {
        // 1. CPU (using cumulative ticks for delta computation)
        let cpuResult = collectCPUInfo(previousTicks: previousCPUTicks)
        cpu = cpuResult.snapshot
        previousCPUTicks = cpuResult.ticks

        // 2. Memory
        memory = collectMemoryInfo()

        // 3. Network — `collectNetworkInfo` walks the interface table and
        //    computes the throughput delta itself; we just feed it the
        //    previous sample so it has a baseline.
        let net = collectNetworkInfo(previous: previousNetworkSample)
        previousNetworkSample = net

        smoothDownload = smoothAlpha * net.downloadSpeed + (1 - smoothAlpha) * smoothDownload
        smoothUpload   = smoothAlpha * net.uploadSpeed   + (1 - smoothAlpha) * smoothUpload

        network = NetworkSnapshot(
            downloadSpeed: net.downloadSpeed,
            uploadSpeed: net.uploadSpeed,
            smoothedDownloadSpeed: smoothDownload,
            smoothedUploadSpeed: smoothUpload,
            timestamp: Date()
        )

        // 4. Thermal — update immediately from the enum (cheap), then
        //    refresh the optional battery temp in a background task.
        thermal = ThermalSnapshot(state: ProcessInfo.processInfo.thermalState, batteryTempCelsius: nil, timestamp: Date())
        let capturedSelf = self
        Task.detached(priority: .background) {
            let batteryTemp = collectBatteryTemperatureFromIOReg()
            await MainActor.run {
                capturedSelf.thermal = ThermalSnapshot(
                    state: ProcessInfo.processInfo.thermalState,
                    batteryTempCelsius: batteryTemp,
                    timestamp: Date()
                )
            }
        }

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
