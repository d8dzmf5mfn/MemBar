import XCTest
@testable import MemBar

@MainActor
final class StatusBarIconViewTests: XCTestCase {
    func test_statusBarImageUsesAppKitCoordinateSystem() {
        let view = StatusBarIconView(frame: .zero)

        XCTAssertFalse(view.isFlipped)
    }

    func test_menuBarRendererMatchesExpandedDonutDirection() {
        XCTAssertTrue(MenuBarRenderer.donutArcClockwise)
        XCTAssertEqual(
            MenuBarRenderer.donutArcEndAngle(for: 0.25),
            0,
            accuracy: 0.0001
        )
    }
}
