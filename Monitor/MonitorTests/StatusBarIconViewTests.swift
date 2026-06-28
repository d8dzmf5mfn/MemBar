import XCTest
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

    func test_settingsMenuActionUsesStandardSwiftUISettingsSelector() {
        XCTAssertEqual(AppDelegate.settingsMenuTitle, "Settings")
        XCTAssertEqual(AppDelegate.showSettingsSelector.description, "showSettingsWindow:")
    }
}
