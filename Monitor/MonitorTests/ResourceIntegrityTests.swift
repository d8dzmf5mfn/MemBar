import XCTest

@MainActor
final class ResourceIntegrityTests: XCTestCase {
    func test_ttfResourcesContainFontData() throws {
        let fontURLs = Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? []

        XCTAssertFalse(fontURLs.isEmpty, "Expected at least one bundled TTF resource.")

        for url in fontURLs {
            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            XCTAssertTrue(
                data.hasTrueTypeMagicBytes,
                "\(url.lastPathComponent) is not a valid TTF/OTF/TTC font resource."
            )
        }
    }
}

private extension Data {
    var hasTrueTypeMagicBytes: Bool {
        guard count >= 4 else { return false }

        let bytes = Array(prefix(4))
        return bytes == [0x00, 0x01, 0x00, 0x00]
            || bytes == Array("OTTO".utf8)
            || bytes == Array("ttcf".utf8)
    }
}
