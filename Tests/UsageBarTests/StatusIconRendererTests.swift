import XCTest
@testable import UsageBar

final class StatusIconRendererTests: XCTestCase {
    func testRendersSingleMenuBarImageForThreeMetrics() {
        let image = StatusIconRenderer.image(for: .placeholder, statusBarThickness: 22)

        XCTAssertEqual(image.size.height, 22)
        XCTAssertGreaterThan(image.size.width, 60)
    }

    func testImageSizeFollowsStatusBarThickness() {
        let compact = StatusIconRenderer.imageSize(forStatusBarThickness: 20)
        let regular = StatusIconRenderer.imageSize(forStatusBarThickness: 22)

        XCTAssertEqual(compact.height, 20)
        XCTAssertEqual(regular.height, 22)
        XCTAssertGreaterThan(regular.width, compact.width)
    }
}
