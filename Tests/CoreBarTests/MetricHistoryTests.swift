import XCTest
@testable import CoreBar

final class MetricHistoryTests: XCTestCase {
    func testKeepsOnlyNewestSamples() {
        var history = MetricHistory.empty

        for index in 0..<35 {
            history.append(snapshot(value: Double(index) / 100), maxCount: 30)
        }

        XCTAssertEqual(history.values(for: .cpu).count, 30)
        XCTAssertEqual(history.values(for: .memory).count, 30)
        XCTAssertEqual(history.values(for: .disk).count, 30)
        XCTAssertEqual(history.values(for: .network).count, 30)
        XCTAssertEqual(history.values(for: .cpu).first, 0.05)
        XCTAssertEqual(history.values(for: .cpu).last, 0.34)
    }

    func testNetworkHistoryTracksDisplayedTotalThroughput() {
        var history = MetricHistory.empty
        let metric = MetricSnapshot(
            kind: .cpu,
            title: "CPU",
            symbol: "cpu",
            value: 0.25,
            detail: "",
            level: .normal,
            usedBytes: nil,
            totalBytes: nil,
            freeBytes: nil,
            coreCount: nil
        )
        let sample = SystemSnapshot(
            cpu: metric,
            memory: metric,
            disk: metric,
            network: NetworkSnapshot(downloadBytesPerSecond: 2_000, uploadBytesPerSecond: 500),
            timestamp: .now
        )

        history.append(sample, maxCount: 30)

        XCTAssertEqual(history.values(for: .network), [2_500])
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

        return SystemSnapshot(
            cpu: metric,
            memory: metric,
            disk: metric,
            network: NetworkSnapshot(downloadBytesPerSecond: value * 1_000, uploadBytesPerSecond: 0),
            timestamp: .now
        )
    }
}
