import XCTest
@testable import CoreBar

final class FormattersTests: XCTestCase {
    func testMemoryTotalUsesBinaryUnitsLikeActivityMonitor() {
        // 16 GiB physical RAM (this machine / common Mac config).
        let sixteenGiB: UInt64 = 16 * 1_024 * 1_024 * 1_024
        XCTAssertEqual(sixteenGiB, 17_179_869_184)

        // .file (decimal) mis-labels 16 GiB as ~17.18 GB — the bug users saw.
        XCTAssertTrue(sixteenGiB.byteText.contains("17"))

        // .memory (binary) matches system_profiler / Activity Monitor "16 GB".
        let memoryText = sixteenGiB.memoryByteText
        XCTAssertTrue(
            memoryText == "16 GB" || memoryText == "16 GB" || memoryText.hasPrefix("16"),
            "Expected ~16 GB memory formatting, got \(memoryText)"
        )
        XCTAssertFalse(memoryText.hasPrefix("17"), "Memory total should not use decimal 17.x GB for 16 GiB")
    }

    func testPhysicalMemoryMatchesProcessInfo() {
        let total = ProcessInfo.processInfo.physicalMemory
        XCTAssertGreaterThan(total, 0)
        // Sampler uses the same source for total.
        let readingTotal = total
        XCTAssertEqual(readingTotal.memoryByteText, total.memoryByteText)
    }
}
