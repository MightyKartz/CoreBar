import Combine
import Foundation

@MainActor
final class SystemMonitor: ObservableObject {
    typealias TimerFactory = (TimeInterval, @escaping @Sendable (Timer) -> Void) -> Timer

    @Published private(set) var snapshot = SystemSnapshot.placeholder
    @Published private(set) var history = MetricHistory.empty

    private let sample: () -> SystemSnapshot
    private let makeTimer: TimerFactory
    private var timer: Timer?
    private var settingsCancellable: AnyCancellable?
    private let maxHistorySamples = 30

    init(
        settings: AppSettings,
        sample: (() -> SystemSnapshot)? = nil,
        makeTimer: @escaping TimerFactory = SystemMonitor.makeScheduledTimer
    ) {
        if let sample {
            self.sample = sample
        } else {
            let sampler = SystemSampler()
            sampler.primeCPU()
            self.sample = { sampler.snapshot() }
        }
        self.makeTimer = makeTimer
        refresh()

        // @Published emits before storage changes. Use its value directly for
        // both the initial timer and every subsequent settings change.
        settingsCancellable = settings.refreshIntervalPublisher
            .removeDuplicates()
            .sink { [weak self] interval in
                self?.startTimer(interval: interval)
            }
    }

    deinit {
        timer?.invalidate()
    }

    private func startTimer(interval: TimeInterval) {
        timer?.invalidate()
        timer = makeTimer(interval) { [weak self] firedTimer in
            Task { @MainActor [weak self] in
                guard let self, self.timer === firedTimer else { return }
                self.refresh()
            }
        }
        timer?.tolerance = min(0.5, interval * 0.15)
    }

    nonisolated private static func makeScheduledTimer(
        interval: TimeInterval,
        handler: @escaping @Sendable (Timer) -> Void
    ) -> Timer {
        let timer = Timer(timeInterval: interval, repeats: true, block: handler)
        // Keep sampling while a menu or another tracking interaction is open.
        RunLoop.main.add(timer, forMode: .common)
        return timer
    }

    private func refresh() {
        let nextSnapshot = sample()
        snapshot = nextSnapshot
        history.append(nextSnapshot, maxCount: maxHistorySamples)
    }
}
