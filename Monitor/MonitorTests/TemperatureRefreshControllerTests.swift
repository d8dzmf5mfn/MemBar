import XCTest
@testable import MemBar

@MainActor
final class TemperatureRefreshControllerTests: XCTestCase {
    func test_refreshIfNeeded_onlyRunsWhenIntervalElapsed() {
        let provider = CountingTemperatureProvider()
        let controller = TemperatureRefreshController(
            minimumInterval: 15,
            currentTime: { provider.now },
            fetchTemperature: {
                provider.callCount += 1
                return 32
            }
        )

        XCTAssertEqual(controller.refreshIfNeeded(), 32)
        provider.now = 5
        XCTAssertNil(controller.refreshIfNeeded())
        provider.now = 16
        XCTAssertEqual(controller.refreshIfNeeded(), 32)
        XCTAssertEqual(provider.callCount, 2)
    }
}

private final class CountingTemperatureProvider {
    var now: TimeInterval = 0
    var callCount = 0
}
