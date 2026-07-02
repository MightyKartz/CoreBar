import XCTest
@testable import UsageBar

final class MetricHistoryTests: XCTestCase {
    func testKeepsOnlyNewestSamples() {
        var history = MetricHistory.empty

        for index in 0..<35 {
            history.append(snapshot(value: Double(index) / 100), maxCount: 30)
        }

        XCTAssertEqual(history.values(for: .cpu).count, 30)
        XCTAssertEqual(history.values(for: .memory).count, 30)
        XCTAssertEqual(history.values(for: .disk).count, 30)
        XCTAssertEqual(history.values(for: .cpu).first, 0.05)
        XCTAssertEqual(history.values(for: .cpu).last, 0.34)
    }

    private func snapshot(value: Double) -> SystemSnapshot {
        let metric = MetricSnapshot(
            kind: .cpu,
            title: "CPU",
            symbol: "cpu",
            value: value,
            detail: "",
            level: .normal,
            usedBytes: nil,
            totalBytes: nil,
            freeBytes: nil,
            coreCount: nil
        )

        return SystemSnapshot(cpu: metric, memory: metric, disk: metric, timestamp: .now)
    }
}
