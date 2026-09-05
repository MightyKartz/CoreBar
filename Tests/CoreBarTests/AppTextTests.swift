import XCTest
@testable import CoreBar

final class AppTextTests: XCTestCase {
    func testLanguageFollowsFirstSupportedPreferenceBeforeRegionalLocale() {
        XCTAssertFalse(AppText.isChinese(localeIdentifier: "zh-Hans_CN", preferredLanguages: ["en-US", "zh-Hans"]))
        XCTAssertTrue(AppText.isChinese(localeIdentifier: "en_US", preferredLanguages: ["zh-Hant-TW", "en-US"]))
        XCTAssertFalse(AppText.isChinese(localeIdentifier: "zh_CN", preferredLanguages: ["fr-FR", "en-GB", "zh-Hans"]))
        XCTAssertTrue(AppText.isChinese(localeIdentifier: "en_US", preferredLanguages: ["fr-FR", "zh_Hans", "en-US"]))
    }

    func testLanguageFallsBackToLocaleWhenPreferencesAreUnsupportedOrMissing() {
        XCTAssertTrue(AppText.isChinese(localeIdentifier: "zh-Hans_CN", preferredLanguages: []))
        XCTAssertTrue(AppText.isChinese(localeIdentifier: "zh-Hant_TW", preferredLanguages: ["ja-JP"]))
        XCTAssertFalse(AppText.isChinese(localeIdentifier: "en_US", preferredLanguages: ["fr-FR"]))
        XCTAssertFalse(AppText.isChinese(localeIdentifier: "en_US", preferredLanguages: ["en-US"]))
        XCTAssertFalse(AppText.isChinese(localeIdentifier: "", preferredLanguages: []))
    }

    func testLanguageCodeMatchingIsCaseInsensitiveAndRequiresWholeCode() {
        XCTAssertTrue(AppText.isChinese(localeIdentifier: "en_US", preferredLanguages: ["ZH-hans"]))
        XCTAssertFalse(AppText.isChinese(localeIdentifier: "en_US", preferredLanguages: ["zhong", "en-US"]))
    }

    func testHealthPillAndNetworkCopyBranches() {
        XCTAssertEqual(AppText.choose(en: "OK", zh: "良好", isChinese: true), "良好")
        XCTAssertEqual(AppText.choose(en: "OK", zh: "良好", isChinese: false), "OK")
        XCTAssertEqual(AppText.choose(en: "Watch", zh: "注意", isChinese: true), "注意")
        XCTAssertEqual(AppText.choose(en: "Critical", zh: "严重", isChinese: false), "Critical")
        XCTAssertEqual(AppText.choose(en: "Down", zh: "下载", isChinese: true), "下载")
        XCTAssertEqual(AppText.choose(en: "Up", zh: "上传", isChinese: false), "Up")
        XCTAssertEqual(AppText.choose(en: "Live", zh: "实时", isChinese: true), "实时")
    }

    func testHealthPillTitleMatchesLevel() {
        XCTAssertEqual(AppText.healthPillTitle(.normal), AppText.healthPillNormal)
        XCTAssertEqual(AppText.healthPillTitle(.warning), AppText.healthPillWarning)
        XCTAssertEqual(AppText.healthPillTitle(.critical), AppText.healthPillCritical)
    }

    func testHealthPillCopyStaysQuietWhenHealthyAndExpandsForAlerts() {
        XCTAssertEqual(
            AppText.healthPillFullTitle(.normal, metricTitle: "CPU", percent: 0.42),
            AppText.healthPillNormal
        )
        XCTAssertEqual(
            AppText.healthPillFullTitle(.warning, metricTitle: "CPU", percent: 0.81),
            "\(AppText.healthPillWarning) · CPU 81%"
        )
        XCTAssertEqual(
            AppText.healthPillCompactTitle(.critical, metricTitle: "CPU", percent: 0.94),
            "CPU 94%"
        )
        XCTAssertEqual(AppText.healthPillMinimalTitle(.critical, percent: 0.94), "94%")
    }

    func testQuitCopyUsesExplicitAppName() {
        XCTAssertEqual(AppText.choose(en: "Quit CoreBar", zh: "退出 CoreBar", isChinese: true), "退出 CoreBar")
    }

    func testAboutAndSupportCopyIsLocalized() {
        XCTAssertEqual(AppText.choose(en: "About CoreBar", zh: "关于 CoreBar", isChinese: true), "关于 CoreBar")
        XCTAssertEqual(AppText.choose(en: "Privacy Policy", zh: "隐私政策", isChinese: false), "Privacy Policy")
        XCTAssertEqual(AppText.choose(en: "Get Support", zh: "获取支持", isChinese: true), "获取支持")
        XCTAssertEqual(AppLinks.privacyPolicy.host, "github.com")
        XCTAssertEqual(AppLinks.support.host, "github.com")
    }

    @MainActor
    func testAppSettingsDefaultsAndRefreshClamping() {
        let suiteName = "CoreBarTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let settings = AppSettings(defaults: defaults, appliesSystemAppearance: false)
        XCTAssertEqual(settings.refreshInterval, 2)
        XCTAssertTrue(settings.showCPU)
        XCTAssertTrue(settings.showMemory)
        XCTAssertTrue(settings.showDisk)
        XCTAssertTrue(settings.showNetwork)
        XCTAssertTrue(settings.useThresholdColors)
        XCTAssertEqual(settings.panelStyle, .controlCenter)
        XCTAssertEqual(settings.appearanceMode, .system)

        settings.refreshInterval = 100
        XCTAssertEqual(settings.refreshInterval, 10)

        settings.appearanceMode = .dark
        XCTAssertEqual(settings.appearanceMode, .dark)
        XCTAssertEqual(defaults.string(forKey: "appearanceMode"), "dark")

        settings.appearanceMode = .light
        XCTAssertEqual(defaults.string(forKey: "appearanceMode"), "light")

        settings.appearanceMode = .system
        XCTAssertEqual(defaults.string(forKey: "appearanceMode"), "system")
    }

    @MainActor
    func testAppSettingsRestoresOneMenuMetricWhenStoredValuesHideAll() {
        let suiteName = "CoreBarTests.MenuMetrics.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        defaults.set(false, forKey: "showCPU")
        defaults.set(false, forKey: "showMemory")
        defaults.set(false, forKey: "showDisk")

        let settings = AppSettings(defaults: defaults, appliesSystemAppearance: false)

        XCTAssertTrue(settings.showCPU)
        XCTAssertFalse(settings.showMemory)
        XCTAssertFalse(settings.showDisk)
        XCTAssertEqual(settings.visibleMenuKinds, [.cpu])
        XCTAssertTrue(defaults.bool(forKey: "showCPU"))
    }

    @MainActor
    func testAppSettingsPreventsHidingEveryMenuMetricAtRuntime() {
        let suiteName = "CoreBarTests.MenuMetricInvariant.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let settings = AppSettings(defaults: defaults, appliesSystemAppearance: false)
        settings.showMemory = false
        settings.showDisk = false
        settings.showCPU = false

        XCTAssertTrue(settings.showCPU)
        XCTAssertEqual(settings.visibleMenuKinds, [.cpu])
        XCTAssertTrue(defaults.bool(forKey: "showCPU"))
    }

    func testAppearanceModeTitlesAndNSAppearance() {
        XCTAssertEqual(AppearanceMode.system.nsAppearance, nil)
        XCTAssertEqual(AppearanceMode.light.nsAppearance?.name, .aqua)
        XCTAssertEqual(AppearanceMode.dark.nsAppearance?.name, .darkAqua)
        XCTAssertEqual(AppText.choose(en: "Light", zh: "浅色", isChinese: true), "浅色")
        XCTAssertEqual(AppText.choose(en: "Dark", zh: "深色", isChinese: false), "Dark")
        XCTAssertEqual(AppText.choose(en: "Auto", zh: "系统", isChinese: true), "系统")
    }
}
