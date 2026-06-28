import XCTest
@testable import MemBar

@MainActor
final class MetricsEngineTests: XCTestCase {
    func test_refreshNowPublishesCompleteSnapshot() {
        let defaults = makeDefaults()
        let preferences = PreferencesStore(defaults: defaults)
        let engine = MetricsEngine(
            preferences: preferences,
            cpuProvider: AnyMetricProvider { CPUSnapshot.zero },
            memoryProvider: AnyMetricProvider { MemorySnapshot.zero },
            networkProvider: AnyMetricProvider { NetworkSnapshot.zero },
            thermalProvider: AnyMetricProvider { ThermalSnapshot.zero }
        )
        var snapshots: [MetricsSnapshot] = []

        engine.refreshNow { snapshots.append($0) }

        XCTAssertEqual(snapshots.count, 1)
        XCTAssertEqual(snapshots[0].cpu.usagePercent, 0)
        XCTAssertEqual(snapshots[0].memory.totalBytes, 0)
        XCTAssertEqual(snapshots[0].network.downloadSpeed, 0)
        XCTAssertEqual(snapshots[0].thermal.state, .nominal)
    }

    func test_startImmediatelyRefreshesAndUsesPreferencesInterval() {
        let defaults = makeDefaults()
        let preferences = PreferencesStore(defaults: defaults)
        preferences.refreshInterval = 5.0
        let engine = MetricsEngine(
            preferences: preferences,
            cpuProvider: AnyMetricProvider { CPUSnapshot.zero },
            memoryProvider: AnyMetricProvider { MemorySnapshot.zero },
            networkProvider: AnyMetricProvider { NetworkSnapshot.zero },
            thermalProvider: AnyMetricProvider { ThermalSnapshot.zero }
        )
        var refreshCount = 0

        engine.start { _ in refreshCount += 1 }

        XCTAssertEqual(refreshCount, 1)
        XCTAssertTrue(engine.isRunning)
        XCTAssertEqual(engine.activeRefreshInterval, 5.0)
        engine.stop()
    }

    func test_stopInvalidatesActiveTimer() {
        let defaults = makeDefaults()
        let preferences = PreferencesStore(defaults: defaults)
        let engine = MetricsEngine(
            preferences: preferences,
            cpuProvider: AnyMetricProvider { CPUSnapshot.zero },
            memoryProvider: AnyMetricProvider { MemorySnapshot.zero },
            networkProvider: AnyMetricProvider { NetworkSnapshot.zero },
            thermalProvider: AnyMetricProvider { ThermalSnapshot.zero }
        )

        engine.start { _ in }
        engine.stop()

        XCTAssertFalse(engine.isRunning)
    }

    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "MetricsEngineTests-\(UUID().uuidString)")!
    }
}

private extension CPUSnapshot {
    static var zero: CPUSnapshot {
        CPUSnapshot(usagePercent: 0, perCoreUsage: [], systemPercent: 0, userPercent: 0, idlePercent: 0, timestamp: Date())
    }
}

private extension MemorySnapshot {
    static var zero: MemorySnapshot {
        MemorySnapshot(totalBytes: 0, usedBytes: 0, freeBytes: 0, wiredBytes: 0, compressedBytes: 0, purgeableBytes: 0, speculativeBytes: 0, appMemoryBytes: 0, usagePercent: 0, timestamp: Date())
    }
}

private extension NetworkSnapshot {
    static var zero: NetworkSnapshot {
        NetworkSnapshot(downloadSpeed: 0, uploadSpeed: 0, smoothedDownloadSpeed: 0, smoothedUploadSpeed: 0, timestamp: Date())
    }
}

private extension ThermalSnapshot {
    static var zero: ThermalSnapshot {
        ThermalSnapshot(state: .nominal, batteryTempCelsius: nil, timestamp: Date())
    }
}
