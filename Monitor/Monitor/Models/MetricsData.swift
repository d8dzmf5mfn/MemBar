import Foundation

struct SystemSnapshot {
    var cpu: CPUSnapshot
    var memory: MemorySnapshot
    var network: NetworkSnapshot
    var `self`: SelfSnapshot
}

struct CPUSnapshot {
    var usagePercent: Double
    var perCoreUsage: [Double]
    var systemPercent: Double
    var userPercent: Double
    var idlePercent: Double
    var timestamp: Date

    nonisolated init(usagePercent: Double, perCoreUsage: [Double], systemPercent: Double, userPercent: Double, idlePercent: Double, timestamp: Date) {
        self.usagePercent = usagePercent
        self.perCoreUsage = perCoreUsage
        self.systemPercent = systemPercent
        self.userPercent = userPercent
        self.idlePercent = idlePercent
        self.timestamp = timestamp
    }
}

struct MemorySnapshot {
    var totalBytes: UInt64
    var usedBytes: UInt64
    var freeBytes: UInt64
    var wiredBytes: UInt64
    var compressedBytes: UInt64
    var purgeableBytes: UInt64
    var speculativeBytes: UInt64
    var appMemoryBytes: UInt64
    var usagePercent: Double
    var timestamp: Date

    nonisolated init(totalBytes: UInt64, usedBytes: UInt64, freeBytes: UInt64, wiredBytes: UInt64, compressedBytes: UInt64, purgeableBytes: UInt64, speculativeBytes: UInt64, appMemoryBytes: UInt64, usagePercent: Double, timestamp: Date) {
        self.totalBytes = totalBytes
        self.usedBytes = usedBytes
        self.freeBytes = freeBytes
        self.wiredBytes = wiredBytes
        self.compressedBytes = compressedBytes
        self.purgeableBytes = purgeableBytes
        self.speculativeBytes = speculativeBytes
        self.appMemoryBytes = appMemoryBytes
        self.usagePercent = usagePercent
        self.timestamp = timestamp
    }
}

struct NetworkSnapshot {
    var downloadSpeed: Double
    var uploadSpeed: Double
    var smoothedDownloadSpeed: Double
    var smoothedUploadSpeed: Double
    var totalDownloaded: UInt64
    var totalUploaded: UInt64
    var timestamp: Date

    nonisolated init(downloadSpeed: Double, uploadSpeed: Double, smoothedDownloadSpeed: Double, smoothedUploadSpeed: Double, totalDownloaded: UInt64, totalUploaded: UInt64, timestamp: Date) {
        self.downloadSpeed = downloadSpeed
        self.uploadSpeed = uploadSpeed
        self.smoothedDownloadSpeed = smoothedDownloadSpeed
        self.smoothedUploadSpeed = smoothedUploadSpeed
        self.totalDownloaded = totalDownloaded
        self.totalUploaded = totalUploaded
        self.timestamp = timestamp
    }
}

struct SelfSnapshot {
    var memoryUsageMB: Double
    var cpuUsagePercent: Double
    var powerEstimateMW: Double
    var timestamp: Date

    nonisolated init(memoryUsageMB: Double, cpuUsagePercent: Double, powerEstimateMW: Double, timestamp: Date) {
        self.memoryUsageMB = memoryUsageMB
        self.cpuUsagePercent = cpuUsagePercent
        self.powerEstimateMW = powerEstimateMW
        self.timestamp = timestamp
    }
}

struct ThermalSnapshot {
    var state: ProcessInfo.ThermalState
    var batteryTempCelsius: Double?
    var timestamp: Date

    init(state: ProcessInfo.ThermalState, batteryTempCelsius: Double?, timestamp: Date) {
        self.state = state
        self.batteryTempCelsius = batteryTempCelsius
        self.timestamp = timestamp
    }

    var label: String {
        switch state {
        case .nominal:  "正常"
        case .fair:     "温热"
        case .serious:  "较热"
        case .critical: "过热"
        @unknown default: "未知"
        }
    }
}

enum AppMode: String, CaseIterable {
    case menuBar
    case fullApp
}
