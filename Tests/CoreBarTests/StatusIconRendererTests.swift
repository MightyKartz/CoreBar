import XCTest
@testable import CoreBar

final class StatusIconRendererTests: XCTestCase {
    func testRendersSingleMenuBarImageForThreeMetrics() {
        let image = StatusIconRenderer.image(for: .placeholder, statusBarThickness: 22)

        XCTAssertEqual(image.size.height, 22)
        XCTAssertEqual(image.size.width, 72)
    }

    func testRendersWithDarkAppearance() throws {
        let appearance = try XCTUnwrap(NSAppearance(named: .darkAqua))
        let image = StatusIconRenderer.image(for: .placeholder, statusBarThickness: 22, appearance: appearance)

        XCTAssertEqual(image.size.height, 22)
        XCTAssertEqual(image.size.width, 72)
    }

    func testImageSizeFollowsStatusBarThickness() {
        let compact = StatusIconRenderer.imageSize(forStatusBarThickness: 20)
        let regular = StatusIconRenderer.imageSize(forStatusBarThickness: 22)

        XCTAssertEqual(compact.height, 20)
        XCTAssertEqual(regular.height, 22)
        XCTAssertGreaterThan(regular.width, compact.width)
    }
}
