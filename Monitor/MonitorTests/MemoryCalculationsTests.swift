import XCTest
@testable import MemBar

final class MemoryCalculationsTests: XCTestCase {
    func test_totalZero_returnsZeroUsage() {
        let result = calculateMemoryUsage(
            totalBytes: 0,
            freeBytes: 20,
            inactiveBytes: 40,
            purgeableBytes: 30,
            speculativeBytes: 20
        )

        XCTAssertEqual(result.usedBytes, 0)
        XCTAssertEqual(result.usagePercent, 0)
    }

    func test_usedMemory_fallsBackToTotalMinusFreeWhenBreakdownExceedsTotal() {
        let result = calculateMemoryUsage(
            totalBytes: 100,
            freeBytes: 20,
            inactiveBytes: 40,
            purgeableBytes: 30,
            speculativeBytes: 20
        )

        XCTAssertEqual(result.usedBytes, 80)
        XCTAssertEqual(result.usagePercent, 80, accuracy: 0.001)
    }
}
