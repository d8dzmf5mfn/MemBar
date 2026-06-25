import Darwin
import Foundation

/// Raw network measurement result. We need the cumulative byte counters
/// in SystemMonitor for the next delta calculation, but we don't want
/// them exposed in the public `NetworkSnapshot` because no view reads
/// them — the speeds are all the views need. `NetworkSample` keeps the
/// counters out of the public API surface.
struct NetworkSample {
    var downloadSpeed: Double      // bytes per second
    var uploadSpeed: Double        // bytes per second
    var receivedBytesByInterface: [String: UInt64]
    var sentBytesByInterface: [String: UInt64]
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
            receivedBytesByInterface: [:], sentBytesByInterface: [:],
            timestamp: Date()
        )
    }

    var counters: [InterfaceCounter] = []

    var ptr = firstAddr
    while true {
        let addr = ptr.pointee
        let name = String(cString: addr.ifa_name)

        if addr.ifa_addr.pointee.sa_family == AF_LINK {
            if let data = addr.ifa_data?.assumingMemoryBound(to: if_data.self).pointee {
                let flags = addr.ifa_flags
                counters.append(InterfaceCounter(
                    name: name,
                    receivedBytes: UInt64(data.ifi_ibytes),
                    sentBytes: UInt64(data.ifi_obytes),
                    isUp: flags & UInt32(IFF_UP) != 0,
                    isLoopback: flags & UInt32(IFF_LOOPBACK) != 0
                ))
            }
        }

        guard let next = addr.ifa_next else { break }
        ptr = next
    }

    freeifaddrs(ifaddrPtr)

    let now = Date()
    let baseline = previous.map {
        NetworkSnapshotBaseline(
            timestamp: $0.timestamp,
            receivedBytesByInterface: $0.receivedBytesByInterface,
            sentBytesByInterface: $0.sentBytesByInterface
        )
    }
    let result = calculateNetworkRates(previous: baseline, current: counters, now: now)

    return NetworkSample(
        downloadSpeed: result.downloadSpeed,
        uploadSpeed: result.uploadSpeed,
        receivedBytesByInterface: result.baseline.receivedBytesByInterface,
        sentBytesByInterface: result.baseline.sentBytesByInterface,
        timestamp: now
    )
}
