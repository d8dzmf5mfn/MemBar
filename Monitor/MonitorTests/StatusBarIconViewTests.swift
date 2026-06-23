import XCTest
@testable import MemBar

@MainActor
final class StatusBarIconViewTests: XCTestCase {
    func test_statusBarImageUsesAppKitCoordinateSystem() {
        let view = StatusBarIconView(frame: .zero)

        XCTAssertFalse(view.isFlipped)
    }

    func test_menuBarRendererDrawsMemoryArcClockwiseFromTwelveOClock() {
        XCTAssertFalse(MenuBarRenderer.donutArcClockwise)
        XCTAssertEqual(
            MenuBarRenderer.donutArcEndAngle(for: 0.25),
            .pi,
            accuracy: 0.0001
        )
    }
}
