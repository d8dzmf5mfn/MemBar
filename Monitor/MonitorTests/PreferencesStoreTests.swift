import XCTest
@testable import MemBar

@MainActor
final class PreferencesStoreTests: XCTestCase {
    func test_defaultsUseMemoryModeRawNetworkAndTwoSecondRefresh() {
        let defaults = makeDefaults()
        let store = PreferencesStore(defaults: defaults)

        XCTAssertEqual(store.menuBarMode, .memory)
        XCTAssertFalse(store.useSmoothNetwork)
        XCTAssertEqual(store.refreshInterval, 2.0)
    }

    func test_valuesPersistThroughUserDefaults() {
        let defaults = makeDefaults()
        let store = PreferencesStore(defaults: defaults)
        store.menuBarMode = .network
        store.useSmoothNetwork = true
        store.refreshInterval = 5.0

        let restored = PreferencesStore(defaults: defaults)
        XCTAssertEqual(restored.menuBarMode, .network)
        XCTAssertTrue(restored.useSmoothNetwork)
        XCTAssertEqual(restored.refreshInterval, 5.0)
    }

    func test_invalidRefreshIntervalFallsBackToTwoSeconds() {
        let defaults = makeDefaults()
        defaults.set(3.5, forKey: PreferencesStore.Keys.refreshInterval)

        let store = PreferencesStore(defaults: defaults)

        XCTAssertEqual(store.refreshInterval, 2.0)
    }

    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "PreferencesStoreTests-\(UUID().uuidString)")!
    }
}
