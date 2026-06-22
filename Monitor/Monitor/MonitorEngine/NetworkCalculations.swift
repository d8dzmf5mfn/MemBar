import Foundation

struct InterfaceCounter {
    let name: String
    let receivedBytes: UInt64
    let sentBytes: UInt64
}

struct NetworkSnapshotBaseline {
    let timestamp: Date
    let receivedBytesByInterface: [String: UInt64]
    let sentBytesByInterface: [String: UInt64]
}

struct NetworkRateResult {
    let downloadSpeed: Double
    let uploadSpeed: Double
    let baseline: NetworkSnapshotBaseline
}

nonisolated func calculateNetworkRates(
    previous: NetworkSnapshotBaseline?,
    current: [InterfaceCounter],
    now: Date
) -> NetworkRateResult {
    let filtered = current.filter { $0.name.hasPrefix("en") || $0.name.hasPrefix("ap") }
    let baseline = NetworkSnapshotBaseline(
        timestamp: now,
        receivedBytesByInterface: Dictionary(uniqueKeysWithValues: filtered.map { ($0.name, $0.receivedBytes) }),
        sentBytesByInterface: Dictionary(uniqueKeysWithValues: filtered.map { ($0.name, $0.sentBytes) })
    )

    guard let previous else {
        return NetworkRateResult(downloadSpeed: 0, uploadSpeed: 0, baseline: baseline)
    }

    let interval = now.timeIntervalSince(previous.timestamp)
    guard interval > 0 else {
        return NetworkRateResult(downloadSpeed: 0, uploadSpeed: 0, baseline: baseline)
    }

    var receivedDelta: UInt64 = 0
    var sentDelta: UInt64 = 0

    for counter in filtered {
        guard let previousReceived = previous.receivedBytesByInterface[counter.name],
              let previousSent = previous.sentBytesByInterface[counter.name] else {
            continue
        }

        let nextReceived = counter.receivedBytes >= previousReceived ? counter.receivedBytes - previousReceived : 0
        let nextSent = counter.sentBytes >= previousSent ? counter.sentBytes - previousSent : 0
        receivedDelta &+= nextReceived
        sentDelta &+= nextSent
    }

    return NetworkRateResult(
        downloadSpeed: Double(receivedDelta) / interval,
        uploadSpeed: Double(sentDelta) / interval,
        baseline: baseline
    )
}
