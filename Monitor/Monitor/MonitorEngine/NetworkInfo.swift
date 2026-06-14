import Foundation

/// Raw network measurement result. We need the cumulative byte counters
/// in SystemMonitor for the next delta calculation, but we don't want
/// them exposed in the public `NetworkSnapshot` because no view reads
/// them — the speeds are all the views need. `NetworkSample` keeps the
/// counters out of the public API surface.
struct NetworkSample {
    var downloadSpeed: Double      // bytes per second
    var uploadSpeed: Double        // bytes per second
    var downloadTotalBytes: UInt64 // cumulative, for the next delta
    var uploadTotalBytes: UInt64   // cumulative, for the next delta
    var timestamp: Date
}

/// Measure current throughput by walking the interface table and
/// computing the delta since the previous sample. On the first call
/// (when `previous` is nil) we report zero speed — there's no baseline
/// yet.
nonisolated func collectNetworkInfo(previous: NetworkSample?) -> NetworkSample {
    var ifaddrPtr: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&ifaddrPtr) == 0, let firstAddr = ifaddrPtr else {
        return NetworkSample(
            downloadSpeed: 0, uploadSpeed: 0,
            downloadTotalBytes: 0, uploadTotalBytes: 0,
            timestamp: Date()
        )
    }

    var totalRx: UInt64 = 0
    var totalTx: UInt64 = 0

    var ptr = firstAddr
    while true {
        let addr = ptr.pointee
        let name = String(cString: addr.ifa_name)

        // Only count physical interfaces (en* = ethernet/wifi, ap* = awdl).
        // Loops / tunnels / bridges are excluded so the gauge reflects
        // real internet activity, not loopback chatter.
        if addr.ifa_addr.pointee.sa_family == AF_LINK,
           name.hasPrefix("en") || name.hasPrefix("ap") {
            if let data = addr.ifa_data?.assumingMemoryBound(to: if_data.self).pointee {
                totalRx += UInt64(data.ifi_ibytes)
                totalTx += UInt64(data.ifi_obytes)
            }
        }

        guard let next = addr.ifa_next else { break }
        ptr = next
    }

    freeifaddrs(ifaddrPtr)

    let now = Date()
    let downloadSpeed: Double
    let uploadSpeed: Double

    if let prev = previous {
        let interval = now.timeIntervalSince(prev.timestamp)
        if interval > 0 {
            // `&-` is wrapping subtraction so a counter reset (e.g. interface
            // bounce) can't trap us on a negative UInt64.
            downloadSpeed = Double(totalRx &- prev.downloadTotalBytes) / interval
            uploadSpeed   = Double(totalTx &- prev.uploadTotalBytes) / interval
        } else {
            downloadSpeed = 0
            uploadSpeed = 0
        }
    } else {
        downloadSpeed = 0
        uploadSpeed = 0
    }

    return NetworkSample(
        downloadSpeed: max(downloadSpeed, 0),
        uploadSpeed: max(uploadSpeed, 0),
        downloadTotalBytes: totalRx,
        uploadTotalBytes: totalTx,
        timestamp: now
    )
}
