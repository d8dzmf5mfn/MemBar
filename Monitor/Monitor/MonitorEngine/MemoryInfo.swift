import Foundation

nonisolated func collectMemoryInfo() -> MemorySnapshot {
    let host = mach_host_self()
    var size = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
    var vmStat = vm_statistics64_data_t()

    let result = withUnsafeMutablePointer(to: &vmStat) {
        $0.withMemoryRebound(to: integer_t.self, capacity: Int(size)) {
            host_statistics64(host, HOST_VM_INFO64, $0, &size)
        }
    }

    guard result == KERN_SUCCESS else {
        return MemorySnapshot(totalBytes: 0, usedBytes: 0, freeBytes: 0, wiredBytes: 0, compressedBytes: 0, purgeableBytes: 0, speculativeBytes: 0, appMemoryBytes: 0, usagePercent: 0, timestamp: Date())
    }

    var pageSizeValue: vm_size_t = 0
    guard host_page_size(host, &pageSizeValue) == KERN_SUCCESS else {
        return MemorySnapshot(totalBytes: 0, usedBytes: 0, freeBytes: 0, wiredBytes: 0, compressedBytes: 0, purgeableBytes: 0, speculativeBytes: 0, appMemoryBytes: 0, usagePercent: 0, timestamp: Date())
    }

    let pageSize = UInt64(pageSizeValue)
    let total = ProcessInfo.processInfo.physicalMemory

    let freeBytes = UInt64(vmStat.free_count) * pageSize
    let inactiveBytes = UInt64(vmStat.inactive_count) * pageSize
    let wiredBytes = UInt64(vmStat.wire_count) * pageSize
    let compressedBytes = UInt64(vmStat.compressor_page_count) * pageSize
    let purgeableBytes = UInt64(vmStat.purgeable_count) * pageSize
    let speculativeBytes = UInt64(vmStat.speculative_count) * pageSize

    let memoryUsage = calculateMemoryUsage(
        totalBytes: total,
        freeBytes: freeBytes,
        inactiveBytes: inactiveBytes,
        purgeableBytes: purgeableBytes,
        speculativeBytes: speculativeBytes
    )

    return MemorySnapshot(
        totalBytes: total,
        usedBytes: memoryUsage.usedBytes,
        freeBytes: freeBytes,
        wiredBytes: wiredBytes,
        compressedBytes: compressedBytes,
        purgeableBytes: purgeableBytes,
        speculativeBytes: speculativeBytes,
        appMemoryBytes: 0,
        usagePercent: memoryUsage.usagePercent,
        timestamp: Date()
    )
}
