import XCTest
@testable import MemBar

final class NetworkCalculationsTests: XCTestCase {
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
}
