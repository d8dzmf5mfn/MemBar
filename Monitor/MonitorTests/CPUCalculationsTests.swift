import XCTest
@testable import MemBar

@MainActor
final class CPUCalculationsTests: XCTestCase {
    func test_firstSample_returnsZeroUsage() {
        let current = [CPUResult(user: 10, system: 10, idle: 80, nice: 0)]

        let result = calculateCPUUsage(previous: nil, current: current)

        XCTAssertEqual(result.usagePercent, 0)
        XCTAssertEqual(result.perCoreUsage, [0])
    }

    func test_deltaSample_returnsUsageFromTickDifferences() {
        let previous = [CPUResult(user: 10, system: 20, idle: 70, nice: 0)]
        let current = [CPUResult(user: 20, system: 30, idle: 90, nice: 0)]

        let result = calculateCPUUsage(previous: previous, current: current)

        XCTAssertEqual(result.usagePercent, 50, accuracy: 0.001)
        XCTAssertEqual(result.perCoreUsage.count, 1)
        XCTAssertEqual(result.perCoreUsage[0], 50, accuracy: 0.001)
    }

    func test_multiCoreStatePercents_useDeltaTicksAcrossCores() {
        let previous = [
            CPUResult(user: 10, system: 10, idle: 80, nice: 0),
            CPUResult(user: 50, system: 10, idle: 40, nice: 0)
        ]
        let current = [
            CPUResult(user: 20, system: 20, idle: 100, nice: 0),
            CPUResult(user: 70, system: 20, idle: 60, nice: 0)
        ]

        let result = calculateCPUStatePercents(previous: previous, current: current)

        XCTAssertEqual(result.userPercent, 33.333, accuracy: 0.001)
        XCTAssertEqual(result.systemPercent, 22.222, accuracy: 0.001)
        XCTAssertEqual(result.idlePercent, 44.444, accuracy: 0.001)
    }
}
