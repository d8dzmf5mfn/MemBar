import Foundation

struct MemoryUsageResult {
    let usedBytes: UInt64
    let usagePercent: Double
}

nonisolated func calculateMemoryUsage(
    totalBytes: UInt64,
    freeBytes: UInt64,
    inactiveBytes: UInt64,
    purgeableBytes: UInt64,
    speculativeBytes: UInt64
) -> MemoryUsageResult {
    guard totalBytes > 0 else {
        return MemoryUsageResult(usedBytes: 0, usagePercent: 0)
    }

    let excludedBytes = freeBytes &+ inactiveBytes &+ purgeableBytes &+ speculativeBytes
    let usedBytes = totalBytes > excludedBytes ? totalBytes - excludedBytes : totalBytes &- freeBytes
    return MemoryUsageResult(usedBytes: usedBytes, usagePercent: Double(usedBytes) / Double(totalBytes) * 100)
}
