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
        XCTAssertEqual(history.timestamps.count, 30)
        XCTAssertEqual(history.download.count, 30)
        XCTAssertEqual(history.upload.count, 30)
        XCTAssertEqual(history.download.first, 50)
        XCTAssertEqual(history.download.last, 340)
        XCTAssertEqual(history.upload.first, 25)
        XCTAssertEqual(history.upload.last, 170)
        XCTAssertEqual(history.network.first, 75)
        XCTAssertEqual(history.network.last, 510)
        XCTAssertEqual(history.timestamps.first, Date(timeIntervalSince1970: 5))
        XCTAssertEqual(history.timestamps.last, Date(timeIntervalSince1970: 34))
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
        XCTAssertEqual(history.download, [2_000])
        XCTAssertEqual(history.upload, [500])
        XCTAssertEqual(history.timestamps, [sample.timestamp])
    }

    func testCapacityPercentageIsIndependentOfPressureEstimate() {
        func memory(used: UInt64?, total: UInt64?) -> MetricSnapshot {
            MetricSnapshot(kind: .memory, title: "Memory", symbol: "memorychip", value: 0.53,
                           detail: "", level: .normal, usedBytes: used, totalBytes: total,
                           freeBytes: nil, coreCount: nil)
        }
        let metric = memory(used: 94, total: 160)
        XCTAssertEqual(metric.value, 0.53)
        XCTAssertEqual(metric.capacityFraction!, 0.5875, accuracy: 0.0001)
        XCTAssertNil(memory(used: 0, total: 0).capacityFraction)
        XCTAssertNil(memory(used: nil, total: 160).capacityFraction)
        XCTAssertEqual(memory(used: 200, total: 160).capacityFraction, 1)
    }

    func testZeroHistoryLimitClearsEveryAlignedSeries() {
        var history = MetricHistory.empty
        history.append(snapshot(value: 0.5), maxCount: 30)
        history.append(snapshot(value: 0.7), maxCount: 0)
        XCTAssertTrue(history.timestamps.isEmpty)
        XCTAssertTrue(history.download.isEmpty)
        XCTAssertTrue(history.upload.isEmpty)
        XCTAssertTrue(history.values(for: .network).isEmpty)
        XCTAssertTrue(history.values(for: .cpu).isEmpty)
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
            network: NetworkSnapshot(downloadBytesPerSecond: value * 1_000, uploadBytesPerSecond: value * 500),
            timestamp: Date(timeIntervalSince1970: value * 100)
        )
    }
}
