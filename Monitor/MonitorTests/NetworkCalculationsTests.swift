import XCTest
@testable import MemBar

@MainActor
final class NetworkCalculationsTests: XCTestCase {
    func test_counterWrap_doesNotCreateSyntheticSpike() {
        let previous = NetworkSnapshotBaseline(
            timestamp: Date(timeIntervalSince1970: 0),
            receivedBytesByInterface: ["en0": UInt64.max - 10],
            sentBytesByInterface: ["en0": UInt64.max - 5]
        )
        let current = [InterfaceCounter(name: "en0", receivedBytes: 20, sentBytes: 15)]

        let result = calculateNetworkRates(previous: previous, current: current, now: Date(timeIntervalSince1970: 2))

        XCTAssertEqual(result.downloadSpeed, 0)
        XCTAssertEqual(result.uploadSpeed, 0)
    }

    func test_missingInterface_doesNotProduceNegativeTraffic() {
        let previous = NetworkSnapshotBaseline(
            timestamp: Date(timeIntervalSince1970: 10),
            receivedBytesByInterface: ["en0": 1000],
            sentBytesByInterface: ["en0": 2000]
        )
        let current = [InterfaceCounter(name: "en1", receivedBytes: 400, sentBytes: 600)]

        let result = calculateNetworkRates(previous: previous, current: current, now: Date(timeIntervalSince1970: 12))

        XCTAssertEqual(result.downloadSpeed, 0)
        XCTAssertEqual(result.uploadSpeed, 0)
    }

    func test_timeReversal_returnsZeroTraffic() {
        let previous = NetworkSnapshotBaseline(
            timestamp: Date(timeIntervalSince1970: 10),
            receivedBytesByInterface: ["en0": 1000],
            sentBytesByInterface: ["en0": 2000]
        )
        let current = [InterfaceCounter(name: "en0", receivedBytes: 1400, sentBytes: 2600)]

        let result = calculateNetworkRates(previous: previous, current: current, now: Date(timeIntervalSince1970: 9))

        XCTAssertEqual(result.downloadSpeed, 0)
        XCTAssertEqual(result.uploadSpeed, 0)
    }
}
