import XCTest
@testable import CoreBar

final class SystemSamplerTests: XCTestCase {
    func testCachesDiskReadingWithinRefreshInterval() {
        var reads = 0
        let sampler = SystemSampler(diskRefreshInterval: 60) {
            reads += 1
            return DiskReading(free: UInt64(900 - reads), total: 1_000)
        }

        let first = sampler.snapshot(now: Date(timeIntervalSince1970: 0)).disk
        let second = sampler.snapshot(now: Date(timeIntervalSince1970: 30)).disk
        let third = sampler.snapshot(now: Date(timeIntervalSince1970: 61)).disk

        XCTAssertEqual(reads, 2)
        XCTAssertEqual(first.freeBytes, second.freeBytes)
        XCTAssertNotEqual(second.freeBytes, third.freeBytes)
    }

    func testCalculatesNetworkRateFromCounterDelta() {
        var readings = [
            NetworkCounters(receivedBytes: 1_000, transmittedBytes: 2_000),
            NetworkCounters(receivedBytes: 2_000, transmittedBytes: 2_500)
        ]
        let sampler = SystemSampler(diskReader: diskReading) {
            readings.removeFirst()
        }

        let first = sampler.snapshot(now: Date(timeIntervalSince1970: 0)).network
        let second = sampler.snapshot(now: Date(timeIntervalSince1970: 2)).network

        XCTAssertEqual(first.downloadBytesPerSecond, 0)
        XCTAssertEqual(first.uploadBytesPerSecond, 0)
        XCTAssertEqual(second.downloadBytesPerSecond, 500)
        XCTAssertEqual(second.uploadBytesPerSecond, 250)
    }

    func testNetworkRateClampsCounterResetAndZeroElapsedTime() {
        var readings = [
            NetworkCounters(receivedBytes: 2_000, transmittedBytes: 2_000),
            NetworkCounters(receivedBytes: 1_000, transmittedBytes: 3_000),
            NetworkCounters(receivedBytes: 4_000, transmittedBytes: 4_000)
        ]
        let sampler = SystemSampler(diskReader: diskReading) {
            readings.removeFirst()
        }

        _ = sampler.snapshot(now: Date(timeIntervalSince1970: 1))
        let reset = sampler.snapshot(now: Date(timeIntervalSince1970: 2)).network
        let zeroElapsed = sampler.snapshot(now: Date(timeIntervalSince1970: 2)).network

        XCTAssertEqual(reset.downloadBytesPerSecond, 0)
        XCTAssertEqual(reset.uploadBytesPerSecond, 1_000)
        XCTAssertEqual(zeroElapsed.downloadBytesPerSecond, 0)
        XCTAssertEqual(zeroElapsed.uploadBytesPerSecond, 0)
    }

    private func diskReading() -> DiskReading {
        DiskReading(free: 500, total: 1_000)
    }
}
