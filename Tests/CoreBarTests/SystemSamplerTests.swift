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
}
