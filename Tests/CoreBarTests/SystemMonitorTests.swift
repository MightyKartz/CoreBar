import Combine
import XCTest
@testable import CoreBar

final class SystemMonitorTests: XCTestCase {
    @MainActor
    func testChangedIntervalImmediatelyDrivesTimerAndSurvivesReload() {
        withSettings { settings, defaults in
            var timers: [Timer] = []
            let monitor = SystemMonitor(settings: settings, sample: { .placeholder }) { interval, handler in
                let timer = Timer(timeInterval: interval, repeats: true, block: handler)
                timers.append(timer)
                return timer
            }

            XCTAssertEqual(timers.map(\.timeInterval), [2])
            settings.refreshInterval = 5
            XCTAssertEqual(timers.last?.timeInterval, 5)
            XCTAssertFalse(timers[0].isValid)
            settings.refreshInterval = 10
            XCTAssertEqual(timers.last?.timeInterval, 10)
            XCTAssertFalse(timers[1].isValid)
            XCTAssertEqual(defaults.double(forKey: "refreshInterval"), 10)

            let reloaded = AppSettings(defaults: defaults, appliesSystemAppearance: false)
            var restoredTimer: Timer?
            let restoredMonitor = SystemMonitor(settings: reloaded, sample: { .placeholder }) { interval, handler in
                let timer = Timer(timeInterval: interval, repeats: true, block: handler)
                restoredTimer = timer
                return timer
            }
            XCTAssertEqual(restoredTimer?.timeInterval, timers.last?.timeInterval)
            withExtendedLifetime((monitor, restoredMonitor)) {}
        }
    }

    @MainActor
    func testEquivalentSettingsDoNotRestartTimerAndInvalidValuesAreNormalized() {
        withSettings { settings, defaults in
            var intervals: [Double] = []
            let monitor = SystemMonitor(settings: settings, sample: { .placeholder }) { interval, handler in
                intervals.append(interval)
                return Timer(timeInterval: interval, repeats: true, block: handler)
            }
            settings.refreshInterval = 2
            settings.refreshInterval = 100
            settings.refreshInterval = 10
            settings.refreshInterval = .nan
            settings.refreshInterval = .infinity
            XCTAssertEqual(intervals, [2, 10, 2])
            XCTAssertEqual(defaults.double(forKey: "refreshInterval"), 2)
            withExtendedLifetime(monitor) {}
        }
    }

    @MainActor
    func testCorruptStoredIntervalIsNormalizedBeforeTimerStarts() {
        let suite = "CoreBarTests.Monitor.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(100.0, forKey: "refreshInterval")
        let settings = AppSettings(defaults: defaults, appliesSystemAppearance: false)
        var scheduledInterval: Double?
        let monitor = SystemMonitor(settings: settings, sample: { .placeholder }) { interval, handler in
            scheduledInterval = interval
            return Timer(timeInterval: interval, repeats: true, block: handler)
        }
        XCTAssertEqual(scheduledInterval, 10)
        XCTAssertEqual(defaults.double(forKey: "refreshInterval"), 10)
        withExtendedLifetime(monitor) {}
    }

    @MainActor
    func testReplacedTimerCannotAppendAStaleQueuedSample() async {
        let suite = "CoreBarTests.Monitor.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = AppSettings(defaults: defaults, appliesSystemAppearance: false)
        var timers: [Timer] = []
        var sampleCount = 0
        let monitor = SystemMonitor(settings: settings, sample: {
            sampleCount += 1
            return .placeholder
        }) { interval, handler in
            let timer = Timer(timeInterval: interval, repeats: true, block: handler)
            timers.append(timer)
            return timer
        }
        timers[0].fire()
        settings.refreshInterval = 5
        // Let the callback queued by the old timer reach the main actor.
        await Task.yield()
        XCTAssertEqual(sampleCount, 1)
        XCTAssertEqual(monitor.history.cpu.count, 1)

        let updated = expectation(description: "New timer publishes its sample")
        let subscription = monitor.$snapshot.dropFirst().sink { _ in updated.fulfill() }
        timers[1].fire()
        await fulfillment(of: [updated], timeout: 1)
        XCTAssertEqual(sampleCount, 2)
        XCTAssertEqual(monitor.history.cpu.count, 2)
        withExtendedLifetime(subscription) {}
    }

    @MainActor
    func testMonitorDeallocationInvalidatesTimerAndCancelsSettingsSubscription() {
        withSettings { settings, _ in
            var timers: [Timer] = []
            var monitor: SystemMonitor? = SystemMonitor(settings: settings, sample: { .placeholder }) { interval, handler in
                let timer = Timer(timeInterval: interval, repeats: true, block: handler)
                timers.append(timer)
                return timer
            }
            weak var weakMonitor: SystemMonitor?
            weakMonitor = monitor
            XCTAssertNotNil(weakMonitor)
            monitor = nil
            XCTAssertNil(weakMonitor)
            XCTAssertFalse(timers[0].isValid)
            settings.refreshInterval = 5
            XCTAssertEqual(timers.count, 1)
        }
    }

    @MainActor
    private func withSettings(_ body: (AppSettings, UserDefaults) -> Void) {
        let suite = "CoreBarTests.Monitor.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        body(AppSettings(defaults: defaults, appliesSystemAppearance: false), defaults)
    }
}
