import XCTest
import SwiftUI
@testable import MemBar

@MainActor
final class StatusBarIconViewTests: XCTestCase {
    func test_statusBarImageUsesAppKitCoordinateSystem() {
        let view = StatusBarIconView(frame: .zero)

        XCTAssertFalse(view.isFlipped)
    }

    func test_menuBarRendererDrawsVerticallyFlippedArc() {
        XCTAssertEqual(
            MenuBarRenderer.donutArcStartAngle,
            -.pi / 2,
            accuracy: 0.0001
        )
        XCTAssertTrue(MenuBarRenderer.donutArcClockwise)
        XCTAssertEqual(
            MenuBarRenderer.donutArcEndAngle(for: 0.25),
            -.pi,
            accuracy: 0.0001
        )
    }

    func test_settingsWindowControllerCreatesReusableSettingsWindow() {
        let defaults = UserDefaults(suiteName: "SettingsWindowControllerTests-\(UUID().uuidString)")!
        let preferences = PreferencesStore(defaults: defaults)
        let controller = SettingsWindowController(preferences: preferences)

        XCTAssertEqual(AppDelegate.settingsMenuTitle, "Settings")
        XCTAssertEqual(controller.window?.title, AppDelegate.settingsWindowTitle)
        XCTAssertEqual(controller.window?.isReleasedWhenClosed, false)
        XCTAssertTrue(controller.window?.contentViewController is NSHostingController<SettingsView>)
    }

    func test_settingsMenuActionUsesAppDelegateSelector() {
        XCTAssertEqual(AppDelegate.settingsMenuTitle, "Settings")
        XCTAssertEqual(AppDelegate.openSettingsSelector.description, "openSettings:")
    }
}
