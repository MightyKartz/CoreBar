import Darwin
import XCTest
@testable import CoreBar

final class SystemSamplerTests: XCTestCase {
    func testCachesDiskReadingWithinRefreshInterval() {
        var reads = 0
        var uptime = 0.0
        let sampler = SystemSampler(
            diskRefreshInterval: 60,
            diskReader: {
                reads += 1
                return DiskReading(free: UInt64(900 - reads), total: 1_000)
            },
            networkReader: { [:] },
            monotonicClock: { uptime }
        )

        let first = sampler.snapshot(now: Date(timeIntervalSince1970: 0)).disk
        uptime = 30
        let second = sampler.snapshot(now: Date(timeIntervalSince1970: 86_400)).disk
        uptime = 60
        let third = sampler.snapshot(now: Date(timeIntervalSince1970: -86_400)).disk

        XCTAssertEqual(reads, 2)
        XCTAssertEqual(first.freeBytes, second.freeBytes)
        XCTAssertNotEqual(second.freeBytes, third.freeBytes)
    }

    func testCalculatesNetworkRateFromCounterDelta() {
        var uptime = 0.0
        let above32Bits = UInt64(UInt32.max) + 100
        var readings: [NetworkInterfaceCounters?] = [
            [1: NetworkCounters(receivedBytes: above32Bits, transmittedBytes: 2_000)],
            [1: NetworkCounters(receivedBytes: above32Bits + 1_000, transmittedBytes: 2_500)]
        ]
        let sampler = SystemSampler(
            diskReader: diskReading,
            networkReader: { readings.removeFirst() },
            monotonicClock: { uptime }
        )

        let first = sampler.snapshot(now: Date(timeIntervalSince1970: 100)).network
        uptime = 2
        let secondSnapshot = sampler.snapshot(now: Date(timeIntervalSince1970: -100))
        let second = secondSnapshot.network

        XCTAssertEqual(first.downloadBytesPerSecond, 0)
        XCTAssertEqual(first.uploadBytesPerSecond, 0)
        XCTAssertEqual(second.downloadBytesPerSecond, 500)
        XCTAssertEqual(second.uploadBytesPerSecond, 250)
        XCTAssertEqual(secondSnapshot.timestamp, Date(timeIntervalSince1970: -100))
    }

    func testNetworkRateClampsCounterResetAndZeroElapsedTime() {
        var uptime = 1.0
        var readings: [NetworkInterfaceCounters?] = [
            [1: NetworkCounters(receivedBytes: 2_000, transmittedBytes: 2_000)],
            [1: NetworkCounters(receivedBytes: 1_000, transmittedBytes: 3_000)],
            [1: NetworkCounters(receivedBytes: 4_000, transmittedBytes: 4_000)]
        ]
        let sampler = SystemSampler(
            diskReader: diskReading,
            networkReader: { readings.removeFirst() },
            monotonicClock: { uptime }
        )

        _ = sampler.snapshot()
        uptime = 2
        let reset = sampler.snapshot().network
        let zeroElapsed = sampler.snapshot().network

        XCTAssertEqual(reset.downloadBytesPerSecond, 0)
        XCTAssertEqual(reset.uploadBytesPerSecond, 1_000)
        XCTAssertEqual(zeroElapsed.downloadBytesPerSecond, 0)
        XCTAssertEqual(zeroElapsed.uploadBytesPerSecond, 0)
    }

    func testAddingAndRemovingInterfacesDoesNotCountTheirLifetimeTotals() {
        var uptime = 0.0
        var readings: [NetworkInterfaceCounters?] = [
            [1: NetworkCounters(receivedBytes: 1_000, transmittedBytes: 2_000)],
            [
                1: NetworkCounters(receivedBytes: 1_100, transmittedBytes: 2_050),
                2: NetworkCounters(receivedBytes: 9_000_000_000, transmittedBytes: 8_000_000_000)
            ],
            [2: NetworkCounters(receivedBytes: 9_000_000_200, transmittedBytes: 8_000_000_100)],
            [
                1: NetworkCounters(receivedBytes: 1_500, transmittedBytes: 2_500),
                2: NetworkCounters(receivedBytes: 9_000_000_400, transmittedBytes: 8_000_000_200)
            ]
        ]
        let sampler = SystemSampler(
            diskReader: diskReading,
            networkReader: { readings.removeFirst() },
            monotonicClock: { uptime }
        )

        _ = sampler.snapshot()
        uptime = 1
        let added = sampler.snapshot().network
        uptime = 2
        let removed = sampler.snapshot().network
        uptime = 3
        let reappeared = sampler.snapshot().network

        XCTAssertEqual(added.downloadBytesPerSecond, 100)
        XCTAssertEqual(added.uploadBytesPerSecond, 50)
        XCTAssertEqual(removed.downloadBytesPerSecond, 200)
        XCTAssertEqual(removed.uploadBytesPerSecond, 100)
        XCTAssertEqual(reappeared.downloadBytesPerSecond, 200)
        XCTAssertEqual(reappeared.uploadBytesPerSecond, 100)
    }

    func testNetworkReadFailurePreservesBaselineUntilRecovery() {
        var uptime = 0.0
        var readings: [NetworkInterfaceCounters?] = [
            [1: NetworkCounters(receivedBytes: 9_000_000_000, transmittedBytes: 2_000)],
            nil,
            [1: NetworkCounters(receivedBytes: 9_000_000_400, transmittedBytes: 2_200)]
        ]
        let sampler = SystemSampler(
            diskReader: diskReading,
            networkReader: { readings.removeFirst() },
            monotonicClock: { uptime }
        )

        _ = sampler.snapshot()
        uptime = 1
        let failed = sampler.snapshot().network
        uptime = 2
        let recovered = sampler.snapshot().network

        XCTAssertEqual(failed.downloadBytesPerSecond, 0)
        XCTAssertEqual(failed.uploadBytesPerSecond, 0)
        XCTAssertEqual(recovered.downloadBytesPerSecond, 200)
        XCTAssertEqual(recovered.uploadBytesPerSecond, 100)
    }

    func testCPUUsageUsesAllBusyStates() {
        let previous = CPUTicks(user: 10, system: 20, idle: 30, nice: 40)
        let current = CPUTicks(user: 30, system: 30, idle: 95, nice: 45)

        XCTAssertEqual(current.usage(since: previous), 0.35, accuracy: 0.000_001)
        XCTAssertEqual(previous.usage(since: previous), 0)
    }

    func testCPUUsageHandlesIndividual32BitCounterWraps() {
        let previous = CPUTicks(user: .max - 1, system: 10, idle: .max - 3, nice: 20)
        let current = CPUTicks(user: 2, system: 14, idle: 4, nice: 24)

        // user/system/nice each advanced 4 ticks; idle advanced 8 ticks.
        XCTAssertEqual(current.usage(since: previous), 0.6, accuracy: 0.000_001)
        XCTAssertEqual(MemoryLayout.size(ofValue: host_cpu_load_info().cpu_ticks.0), 4)
    }

    func testMemoryEstimateDoesNotCountSpeculativePagesTwice() {
        var stats = vm_statistics64()
        stats.active_count = 40
        stats.wire_count = 10
        stats.compressor_page_count = 5
        stats.free_count = 20
        stats.speculative_count = 10 // Already included in the 20 free pages.
        stats.inactive_count = 30
        stats.purgeable_count = 10

        let reading = SystemSampler.memoryReading(stats: stats, pageBytes: 1_024, total: 100 * 1_024)

        XCTAssertEqual(reading.used, 55 * 1_024)
        XCTAssertEqual(reading.total, 100 * 1_024)
        XCTAssertEqual(reading.pressure, 0.35, accuracy: 0.000_001)
    }

    func testMemoryPageCountsAreWidenedBeforeAdditionAndClampedToTotal() {
        var stats = vm_statistics64()
        stats.free_count = .max
        stats.inactive_count = .max
        let reading = SystemSampler.memoryReading(stats: stats, pageBytes: 1, total: UInt64(UInt32.max) * 3)
        XCTAssertEqual(reading.pressure, 1.0 / 3, accuracy: 0.000_001)

        stats.active_count = 100
        let clamped = SystemSampler.memoryReading(stats: stats, pageBytes: 1_024, total: 1_024)
        XCTAssertEqual(clamped.used, 1_024)
        XCTAssertEqual(clamped.pressure, 0)
        XCTAssertEqual(SystemSampler.memoryReading(stats: stats, pageBytes: 1_024, total: 0).pressure, 0)
    }

    func testDiskReadingClampsFreeSpaceBeforeSubtracting() {
        let reading = DiskReading(free: 2_000, total: 1_000)
        XCTAssertEqual(reading.free, 1_000)
        XCTAssertEqual(reading.usedFraction, 0)
        XCTAssertEqual(DiskReading(free: 1, total: 0).usedFraction, 0)
    }

    private func diskReading() -> DiskReading {
        DiskReading(free: 500, total: 1_000)
    }
}
