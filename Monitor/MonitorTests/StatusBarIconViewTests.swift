import XCTest
@testable import MemBar

@MainActor
final class StatusBarIconViewTests: XCTestCase {
    func test_statusBarImageUsesAppKitCoordinateSystem() {
        let view = StatusBarIconView(frame: .zero)

        XCTAssertFalse(view.isFlipped)
    }
}
