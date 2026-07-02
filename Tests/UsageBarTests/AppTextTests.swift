import XCTest
@testable import UsageBar

final class AppTextTests: XCTestCase {
    func testDetectsChineseFromLocaleOrPreferredLanguages() {
        XCTAssertTrue(AppText.isChinese(localeIdentifier: "zh-Hans_CN", preferredLanguages: []))
        XCTAssertTrue(AppText.isChinese(localeIdentifier: "en_US", preferredLanguages: ["zh-Hant-TW"]))
        XCTAssertFalse(AppText.isChinese(localeIdentifier: "en_US", preferredLanguages: ["en-US"]))
    }
}
