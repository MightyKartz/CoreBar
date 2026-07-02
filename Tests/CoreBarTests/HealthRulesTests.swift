import XCTest
@testable import CoreBar

final class HealthRulesTests: XCTestCase {
    func testDefaultThresholds() {
        XCTAssertEqual(HealthRules.level(for: 0.74), .normal)
        XCTAssertEqual(HealthRules.level(for: 0.75), .warning)
        XCTAssertEqual(HealthRules.level(for: 0.9), .critical)
    }

    func testClampsOutOfRangeValues() {
        XCTAssertEqual(HealthRules.level(for: -1), .normal)
        XCTAssertEqual(HealthRules.level(for: 2), .critical)
    }
}
