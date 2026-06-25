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

    func test_activeNonLoopbackInterfacesContributeToTraffic() {
        let previous = NetworkSnapshotBaseline(
            timestamp: Date(timeIntervalSince1970: 0),
            receivedBytesByInterface: [
                "en0": 1_000,
                "utun4": 2_000,
                "bridge100": 3_000
            ],
            sentBytesByInterface: [
                "en0": 500,
                "utun4": 700,
                "bridge100": 900
            ]
        )
        let current = [
            InterfaceCounter(name: "en0", receivedBytes: 1_200, sentBytes: 650),
            InterfaceCounter(name: "utun4", receivedBytes: 2_300, sentBytes: 900),
            InterfaceCounter(name: "bridge100", receivedBytes: 3_400, sentBytes: 1_150)
        ]

        let result = calculateNetworkRates(previous: previous, current: current, now: Date(timeIntervalSince1970: 2))

        XCTAssertEqual(result.downloadSpeed, 450)
        XCTAssertEqual(result.uploadSpeed, 300)
    }

    func test_inactiveAndLoopbackInterfacesAreIgnored() {
        let previous = NetworkSnapshotBaseline(
            timestamp: Date(timeIntervalSince1970: 0),
            receivedBytesByInterface: [
                "en0": 1_000,
                "lo0": 10_000,
                "utun9": 20_000
            ],
            sentBytesByInterface: [
                "en0": 500,
                "lo0": 10_000,
                "utun9": 20_000
            ]
        )
        let current = [
            InterfaceCounter(name: "en0", receivedBytes: 1_200, sentBytes: 600),
            InterfaceCounter(name: "lo0", receivedBytes: 20_000, sentBytes: 20_000, isLoopback: true),
            InterfaceCounter(name: "utun9", receivedBytes: 30_000, sentBytes: 30_000, isUp: false)
        ]

        let result = calculateNetworkRates(previous: previous, current: current, now: Date(timeIntervalSince1970: 2))

        XCTAssertEqual(result.downloadSpeed, 100)
        XCTAssertEqual(result.uploadSpeed, 50)
        XCTAssertEqual(result.baseline.receivedBytesByInterface.keys.sorted(), ["en0"])
    }
}
