import XCTest
@testable import CoreBar

final class StatusIconRendererTests: XCTestCase {
    func testRendersSingleMenuBarImageForThreeMetrics() {
        let expected = StatusIconRenderer.imageSize(
            forStatusBarThickness: 22,
            visibleKinds: [.cpu, .memory, .disk]
        )
        let image = StatusIconRenderer.image(for: .placeholder, statusBarThickness: 22)

        XCTAssertEqual(image.size.height, 22)
        XCTAssertEqual(image.size.width, expected.width)
        XCTAssertGreaterThan(image.size.width, 60)
        XCTAssertLessThan(image.size.width, 90)
    }

    func testRendersWithDarkAppearance() throws {
        let appearance = try XCTUnwrap(NSAppearance(named: .darkAqua))
        let expected = StatusIconRenderer.imageSize(
            forStatusBarThickness: 22,
            visibleKinds: [.cpu, .memory, .disk]
        )
        let image = StatusIconRenderer.image(for: .placeholder, statusBarThickness: 22, appearance: appearance)

        XCTAssertEqual(image.size.height, 22)
        XCTAssertEqual(image.size.width, expected.width)
    }

    func testImageSizeFollowsStatusBarThickness() {
        let compact = StatusIconRenderer.imageSize(forStatusBarThickness: 20)
        let regular = StatusIconRenderer.imageSize(forStatusBarThickness: 22)

        XCTAssertEqual(compact.height, 20)
        XCTAssertEqual(regular.height, 22)
        XCTAssertGreaterThan(regular.width, compact.width)
    }

    func testImageWidthFollowsVisibleMetrics() {
        let one = StatusIconRenderer.imageSize(forStatusBarThickness: 22, visibleKinds: [.cpu])
        let three = StatusIconRenderer.imageSize(forStatusBarThickness: 22, visibleKinds: [.cpu, .memory, .disk])

        XCTAssertLessThan(one.width, three.width)
        XCTAssertEqual(three.width, StatusIconRenderer.image(for: .placeholder, statusBarThickness: 22).size.width)
    }

    func testBarColorThresholdVersusNeutral() {
        let neutral = StatusIconRenderer.barColor(level: .critical, usesThresholdColors: false)
        let critical = StatusIconRenderer.barColor(level: .critical, usesThresholdColors: true)
        let warning = StatusIconRenderer.barColor(level: .warning, usesThresholdColors: true)
        let normal = StatusIconRenderer.barColor(level: .normal, usesThresholdColors: true)

        XCTAssertEqual(neutral, NSColor.labelColor)
        XCTAssertEqual(critical, DesignTokens.nsRed)
        XCTAssertEqual(warning, DesignTokens.nsOrange)
        XCTAssertEqual(normal, DesignTokens.nsGreen)
        XCTAssertNotEqual(critical, neutral)
    }

    func testStatusLabelAddsNonColorWarningGlyphsOnlyWhenRequested() {
        XCTAssertEqual(
            StatusIconRenderer.statusLabel(for: .cpu, level: .critical, differentiatesWithoutColor: false),
            "CPU"
        )
        XCTAssertEqual(
            StatusIconRenderer.statusLabel(for: .memory, level: .warning, differentiatesWithoutColor: true),
            "MEM△"
        )
        XCTAssertEqual(
            StatusIconRenderer.statusLabel(for: .disk, level: .critical, differentiatesWithoutColor: true),
            "DSK!"
        )
    }
}
