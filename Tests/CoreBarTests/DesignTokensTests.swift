import SwiftUI
import XCTest
@testable import CoreBar

final class DesignTokensTests: XCTestCase {
    func testAccentUsesThresholdSemanticColors() {
        let cpuWarn = DesignTokens.accent(for: .warning, kind: .cpu, usesThresholdColors: true)
        let cpuNeutral = DesignTokens.accent(for: .warning, kind: .cpu, usesThresholdColors: false)
        XCTAssertEqual(cpuWarn, DesignTokens.orange)
        XCTAssertEqual(cpuNeutral, Color.primary)
    }

    func testDiskHealthyUsesBlueWhenThresholdOn() {
        let disk = DesignTokens.accent(for: .normal, kind: .disk, usesThresholdColors: true)
        XCTAssertEqual(disk, DesignTokens.blue)
    }

    func testNetworkUsesIndigoWhenThresholdOn() {
        let network = DesignTokens.accent(for: .normal, kind: .network, usesThresholdColors: true)
        XCTAssertEqual(network, DesignTokens.indigo)
    }

    func testNetworkUsesNeutralWhenThresholdOff() {
        let network = DesignTokens.accent(for: .normal, kind: .network, usesThresholdColors: false)
        XCTAssertEqual(network, Color.primary)
        XCTAssertNotEqual(network, DesignTokens.indigo)
    }

    func testValueAnimationRespectsReduceMotion() {
        XCTAssertNil(DesignTokens.valueAnimation(reduceMotion: true))
        XCTAssertNotNil(DesignTokens.valueAnimation(reduceMotion: false))
    }

    @MainActor
    func testSystemPanelNavigationMovesBetweenOverviewAndSettings() {
        let navigation = SystemPanelNavigationModel()

        XCTAssertEqual(navigation.page, .overview)
        navigation.showSettings()
        XCTAssertEqual(navigation.page, .settings)
        navigation.showOverview()
        XCTAssertEqual(navigation.page, .overview)
    }

    func testPanelWidthTokensMatchPreviewSpec() {
        XCTAssertEqual(DesignTokens.panelWidth, 372)
        XCTAssertEqual(DesignTokens.panelCornerRadius, 28)
        XCTAssertEqual(DesignTokens.tileCornerRadius, 22)
        XCTAssertEqual(DesignTokens.progressHeight, 4)
        XCTAssertEqual(DesignTokens.classicRowMinHeight, 96)
        XCTAssertEqual(DesignTokens.classicProgressHeight, 3)
    }

    func testClassicMetricsUseOneSupportingVisualization() {
        XCTAssertEqual(ClassicMetricVisualization(kind: .cpu), .sparkline)
        XCTAssertEqual(ClassicMetricVisualization(kind: .memory), .progress)
        XCTAssertEqual(ClassicMetricVisualization(kind: .disk), .progress)
        XCTAssertEqual(ClassicMetricVisualization(kind: .network), .sparkline)
    }

    func testAdaptiveMetricGridUsesIntentionalSingletonRows() {
        XCTAssertEqual(AdaptiveMetricGridLayout.rows(for: 0), [])
        XCTAssertEqual(AdaptiveMetricGridLayout.rows(for: 1), [[0]])
        XCTAssertEqual(AdaptiveMetricGridLayout.rows(for: 2), [[0, 1]])
        XCTAssertEqual(AdaptiveMetricGridLayout.rows(for: 3), [[0, 1], [2]])
        XCTAssertEqual(AdaptiveMetricGridLayout.rows(for: 4), [[0, 1], [2, 3]])
    }

    @MainActor
    func testStatusItemRoutesRightClickToContextMenu() {
        XCTAssertEqual(StatusItemController.clickDestination(for: .leftMouseUp), .overview)
        XCTAssertEqual(StatusItemController.clickDestination(for: .rightMouseUp), .contextMenu)
        XCTAssertEqual(StatusItemController.clickDestination(for: nil), .overview)
    }

    @MainActor
    func testCardOverviewUsesRowCountWhileSettingsKeepTheirOwnSize() {
        let suite = "CoreBarTests.Size.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = AppSettings(defaults: defaults, appliesSystemAppearance: false)
        let settingsSize = StatusItemController.settingsPanelSize(settings: settings)

        settings.showMemory = false
        settings.showDisk = false
        settings.showNetwork = false
        let one = ControlCenterPanelView.contentSize(settings: settings)
        settings.showNetwork = true
        let two = ControlCenterPanelView.contentSize(settings: settings)
        settings.showMemory = true
        let three = ControlCenterPanelView.contentSize(settings: settings)
        settings.showDisk = true
        let four = ControlCenterPanelView.contentSize(settings: settings)

        XCTAssertEqual(one, two)
        XCTAssertEqual(three, four)
        XCTAssertLessThan(two.height, four.height)
        XCTAssertLessThan(one.height, settingsSize.height)
        XCTAssertEqual(one.width, settingsSize.width)
        XCTAssertEqual(four.width, settingsSize.width)
        XCTAssertEqual(StatusItemController.settingsPanelSize(settings: settings), settingsSize)

        let navigation = SystemPanelNavigationModel()
        navigation.showSettings()
        XCTAssertEqual(PanelMetricsLayout.systemDefaultPanelSize(settings: settings, page: navigation.page), settingsSize)
        settings.showMemory = false
        settings.showDisk = false
        settings.showNetwork = false
        XCTAssertEqual(PanelMetricsLayout.systemDefaultPanelSize(settings: settings, page: navigation.page), settingsSize)
        navigation.showOverview()
        XCTAssertEqual(PanelMetricsLayout.systemDefaultPanelSize(settings: settings, page: navigation.page), one)
    }

    @MainActor
    func testClassicPanelHeightTracksVisibleRows() {
        let suite = "CoreBarTests.ClassicSize.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let settings = AppSettings(defaults: defaults, appliesSystemAppearance: false)
        settings.panelStyle = .classic
        settings.showCPU = true
        settings.showMemory = false
        settings.showDisk = false
        settings.showNetwork = false
        let oneRow = StatusPanelView.contentSize(settings: settings)

        settings.showMemory = true
        settings.showDisk = true
        settings.showNetwork = true
        let fourRows = StatusPanelView.contentSize(settings: settings)

        XCTAssertEqual(oneRow.width, DesignTokens.panelWidth)
        XCTAssertEqual(fourRows.width, oneRow.width)
        XCTAssertEqual(
            fourRows.height - oneRow.height,
            3 * DesignTokens.classicRowMinHeight,
            accuracy: 0.001
        )
    }

    @MainActor
    func testAppSettingsKeysRemainCompatible() {
        let suite = "CoreBarTests.Keys.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        defaults.set(5.0, forKey: "refreshInterval")
        defaults.set(false, forKey: "showCPU")
        defaults.set(false, forKey: "showMemory")
        defaults.set(true, forKey: "showDisk")
        defaults.set(false, forKey: "showNetwork")
        defaults.set(false, forKey: "useThresholdColors")
        defaults.set("controlCenter", forKey: "panelStyle")
        defaults.set("dark", forKey: "appearanceMode")

        let settings = AppSettings(defaults: defaults, appliesSystemAppearance: false)
        XCTAssertEqual(settings.refreshInterval, 5)
        XCTAssertFalse(settings.showCPU)
        XCTAssertFalse(settings.showMemory)
        XCTAssertTrue(settings.showDisk)
        XCTAssertFalse(settings.showNetwork)
        XCTAssertFalse(settings.useThresholdColors)
        XCTAssertEqual(settings.panelStyle, .controlCenter)
        XCTAssertEqual(settings.appearanceMode, .dark)
    }
}
