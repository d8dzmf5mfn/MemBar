import Foundation

nonisolated func collectNetworkInfo(previous: NetworkSnapshot?) -> NetworkSnapshot {
    var ifaddrPtr: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&ifaddrPtr) == 0, let firstAddr = ifaddrPtr else {
        return NetworkSnapshot(downloadSpeed: 0, uploadSpeed: 0, smoothedDownloadSpeed: 0, smoothedUploadSpeed: 0, totalDownloaded: 0, totalUploaded: 0, timestamp: Date())
    }

    var totalRx: UInt64 = 0
    var totalTx: UInt64 = 0

    var ptr = firstAddr
    while true {
        let addr = ptr.pointee
        let name = String(cString: addr.ifa_name)

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
            downloadSpeed = Double(totalRx - prev.totalDownloaded) / interval
            uploadSpeed = Double(totalTx - prev.totalUploaded) / interval
        } else {
            downloadSpeed = 0
            uploadSpeed = 0
        }
    } else {
        downloadSpeed = 0
        uploadSpeed = 0
    }

    return NetworkSnapshot(
        downloadSpeed: max(downloadSpeed, 0),
        uploadSpeed: max(uploadSpeed, 0),
        smoothedDownloadSpeed: max(downloadSpeed, 0),
        smoothedUploadSpeed: max(uploadSpeed, 0),
        totalDownloaded: totalRx,
        totalUploaded: totalTx,
        timestamp: now
    )
}
