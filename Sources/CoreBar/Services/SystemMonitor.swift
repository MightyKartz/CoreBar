import Combine
import Foundation

@MainActor
final class SystemMonitor: ObservableObject {
    @Published private(set) var snapshot = SystemSnapshot.placeholder
    @Published private(set) var history = MetricHistory.empty

    private let sampler = SystemSampler()
    private var timer: Timer?
    private let maxHistorySamples = 30

    init() {
        sampler.primeCPU()
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
        timer?.tolerance = 0.3
    }

    deinit {
        timer?.invalidate()
    }

    func refresh() {
        let nextSnapshot = sampler.snapshot()
        snapshot = nextSnapshot
        history.append(nextSnapshot, maxCount: maxHistorySamples)
    }
}
