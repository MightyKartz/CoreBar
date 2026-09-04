import XCTest
@testable import CoreBar

final class MetricSparklineTests: XCTestCase {
    func testPercentageAndAdaptiveNormalization() {
        XCTAssertEqual(MetricSparklineView.normalizedValues([0.02, 0.03], fixedRange: 0...1), [0.02, 0.03])
        XCTAssertEqual(MetricSparklineView.normalizedValues([0, 500, 1_000], fixedRange: nil), [0, 0.5, 1])
    }

    func testPointsGeometryForAreaSparkline() {
        let size = CGSize(width: 100, height: 20)
        let points = MetricSparklineView.points(for: [0, 0.5, 1], in: size, fixedRange: 0...1, paddingY: 0)

        XCTAssertEqual(points.count, 3)
        XCTAssertEqual(points[0].x, 0, accuracy: 0.001)
        XCTAssertEqual(points[2].x, 100, accuracy: 0.001)
        // Higher values sit higher on the chart (smaller y in top-left coords).
        XCTAssertGreaterThan(points[0].y, points[1].y)
        XCTAssertGreaterThan(points[1].y, points[2].y)
    }

    func testPointsRequireAtLeastTwoSamples() {
        XCTAssertTrue(MetricSparklineView.points(for: [0.5], in: CGSize(width: 40, height: 20), fixedRange: 0...1).isEmpty)
    }

    func testRollingNetworkCeilingKeepsHeadroomAndStableSteps() {
        XCTAssertEqual(MetricSparklineView.rollingUpperBound(for: []), 128 * 1_024)
        XCTAssertEqual(MetricSparklineView.rollingUpperBound(for: [900_000]), 2_000_000)
        XCTAssertEqual(MetricSparklineView.rollingUpperBound(for: [1_000_000, 1_200_000]), 2_000_000)
        XCTAssertGreaterThan(MetricSparklineView.rollingUpperBound(for: [8_000_000]), 8_000_000)
    }
}
