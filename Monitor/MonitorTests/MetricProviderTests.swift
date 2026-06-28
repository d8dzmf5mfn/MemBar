import XCTest
@testable import MemBar

@MainActor
final class MetricProviderTests: XCTestCase {
    func test_cpuProviderFirstSampleReturnsZeroUsageBaseline() {
        var provider = CPUMetricProvider()

        let snapshot = provider.sample()

        XCTAssertEqual(snapshot.usagePercent, 0)
    }

    func test_memoryProviderReturnsPhysicalMemorySnapshot() {
        var provider = MemoryMetricProvider()

        let snapshot = provider.sample()

        XCTAssertGreaterThanOrEqual(snapshot.totalBytes, 0)
        XCTAssertGreaterThanOrEqual(snapshot.usagePercent, 0)
    }

    func test_networkProviderFirstSampleReturnsZeroThroughput() {
        var provider = NetworkMetricProvider()

        let snapshot = provider.sample()

        XCTAssertEqual(snapshot.downloadSpeed, 0)
        XCTAssertEqual(snapshot.uploadSpeed, 0)
    }

    func test_thermalProviderRespectsMinimumRefreshInterval() {
        let provider = CountingBatteryTemperatureProvider()
        var thermal = ThermalMetricProvider(
            temperatureProvider: provider,
            minimumInterval: 15,
            currentTime: { provider.now }
        )

        XCTAssertEqual(thermal.sample().batteryTempCelsius, 32)
        provider.now = 5
        XCTAssertEqual(thermal.sample().batteryTempCelsius, 32)
        provider.now = 16
        XCTAssertEqual(thermal.sample().batteryTempCelsius, 33)
        XCTAssertEqual(provider.callCount, 2)
    }
}

private final class CountingBatteryTemperatureProvider: BatteryTemperatureProviding {
    var now: TimeInterval = 0
    var callCount = 0

    func batteryTemperatureCelsius() -> Double? {
        callCount += 1
        return Double(31 + callCount)
    }
}
