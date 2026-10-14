import XCTest
@testable import CoreBar

final class MetricSparklineTests: XCTestCase {
    func testUnevenSampleTimesUseActualHorizontalSpacing() {
        let times = [0.0, 1.0, 10.0].map { Date(timeIntervalSince1970: $0) }
        let points = MetricSparklineView.points(for: [0.2, 0.3, 0.4], in: CGSize(width: 100, height: 30), fixedRange: 0...1, timestamps: times)
        XCTAssertEqual(points[1].x, 10, accuracy: 0.01)
        XCTAssertEqual(points.last!.x, 100, accuracy: 0.01)
    }

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

    func testSingleSampleHasVisibleAndInspectablePoint() {
        let date = Date(timeIntervalSince1970: 10)
        let points = MetricSparklineView.points(for: [0.5], in: CGSize(width: 40, height: 20), fixedRange: 0...1, timestamps: [date])
        XCTAssertEqual(points, [CGPoint(x: 20, y: 10)])
        XCTAssertEqual(MetricSparklineView.nearestSampleDate(at: 0, points: points, timestamps: [date]), date)
        XCTAssertTrue(MetricSparklineView.points(for: [], in: CGSize(width: 40, height: 20), fixedRange: 0...1).isEmpty)
    }

    func testInspectionUsesNearestRealSampleAndClampsAtEdges() {
        let dates = [0.0, 1.0, 10.0].map { Date(timeIntervalSince1970: $0) }
        let points = MetricSparklineView.points(for: [0.2, 0.3, 0.4], in: CGSize(width: 100, height: 30), fixedRange: 0...1, timestamps: dates)
        XCTAssertEqual(MetricSparklineView.nearestSampleDate(at: -10, points: points, timestamps: dates), dates[0])
        for x in stride(from: 6.0, through: 54.0, by: 1) {
            XCTAssertEqual(MetricSparklineView.nearestSampleDate(at: x, points: points, timestamps: dates), dates[1])
        }
        XCTAssertEqual(MetricSparklineView.nearestSampleDate(at: 110, points: points, timestamps: dates), dates[2])
        XCTAssertNil(MetricSparklineView.nearestSampleDate(at: 0, points: points, timestamps: []))
    }

    func testInspectionLabelsSeparatePressureCapacityAndCombinedTraffic() {
        let dates = [Date(timeIntervalSince1970: 10)]
        let memory = MetricSparklineView.inspectionSample(at: 0, values: [0.53], timestamps: dates, kind: .memory)
        XCTAssertEqual(memory?.readings.first?.title, AppText.estimatedPressure)
        XCTAssertEqual(memory?.readings.first?.value, "53%")
        let disk = MetricSparklineView.inspectionSample(at: 0, values: [0.94], timestamps: dates, kind: .disk)
        XCTAssertEqual(disk?.readings.first?.title, AppText.inspectionMetricTitle(.disk))
        let network = MetricSparklineView.inspectionSample(at: 0, values: [12_400_000], timestamps: dates, kind: .network)
        XCTAssertEqual(network?.readings.first?.title, AppText.combinedTraffic)
        let dual = MetricSparklineView.inspectionSample(at: 0, values: [6_000_000], timestamps: dates, kind: .network, secondaryValues: [6_400_000])
        XCTAssertEqual(dual?.readings.map(\.title), [AppText.download, AppText.upload])
        XCTAssertEqual(dual?.readings.map(\.value), [Double(6_000_000).byteRateText, Double(6_400_000).byteRateText])
        XCTAssertNil(MetricSparklineView.inspectionSample(at: 0, values: [1], timestamps: [], kind: .cpu))
        XCTAssertNil(MetricSparklineView.inspectionSample(at: 0, values: [1], timestamps: dates, kind: .network, secondaryValues: [1, 2]))
    }

    func testRollingNetworkCeilingKeepsHeadroomAndStableSteps() {
        XCTAssertEqual(MetricSparklineView.rollingUpperBound(for: []), 128 * 1_024)
        XCTAssertEqual(MetricSparklineView.rollingUpperBound(for: [900_000]), 2_000_000)
        XCTAssertEqual(MetricSparklineView.rollingUpperBound(for: [1_000_000, 1_200_000]), 2_000_000)
        XCTAssertGreaterThan(MetricSparklineView.rollingUpperBound(for: [8_000_000]), 8_000_000)
    }
}
