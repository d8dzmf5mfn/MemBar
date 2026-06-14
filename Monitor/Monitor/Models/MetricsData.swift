import Foundation

// MARK: - Data snapshots
// =====================================================
// Plain value types — `init` is auto-synthesized by the compiler.
// `collectXxxInfo()` helpers in MonitorEngine call these initializers
// from `nonisolated` contexts; the auto-synthesized init is `nonisolated`
// by default for structs with no actor isolation, which is what we want.
// =====================================================

struct CPUSnapshot {
    var usagePercent: Double
    var perCoreUsage: [Double]
    var systemPercent: Double
    var userPercent: Double
    var idlePercent: Double
    var timestamp: Date
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
}

struct NetworkSnapshot {
    var downloadSpeed: Double
    var uploadSpeed: Double
    var smoothedDownloadSpeed: Double
    var smoothedUploadSpeed: Double
    var timestamp: Date
}

struct ThermalSnapshot {
    var state: ProcessInfo.ThermalState
    var batteryTempCelsius: Double?
    var timestamp: Date

    /// Localized label for the current thermal state.
    /// `label` was promoted from a private extension here so it's
    /// discoverable in one place.
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
