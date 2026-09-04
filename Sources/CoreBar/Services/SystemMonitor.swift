import AppKit
import Combine
import Foundation

enum PanelStyle: String, CaseIterable, Identifiable {
    case classic
    case controlCenter

    var id: String { rawValue }

    var title: String {
        switch self {
        case .classic: AppText.classicPanel
        case .controlCenter: AppText.controlCenterPanel
        }
    }
}

/// App-wide color appearance override (Settings → 浅色 / 深色 / 系统默认).
enum AppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: AppText.appearanceSystem
        case .light: AppText.appearanceLight
        case .dark: AppText.appearanceDark
        }
    }

    /// `nil` follows macOS system appearance.
    var nsAppearance: NSAppearance? {
        switch self {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }
}

@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published private var refreshIntervalStorage: Double
    @Published var showCPU: Bool {
        didSet {
            if !showCPU && !showMemory && !showDisk {
                showCPU = true
            }
            defaults.set(showCPU, forKey: Keys.showCPU)
        }
    }
    @Published var showMemory: Bool {
        didSet {
            if !showCPU && !showMemory && !showDisk {
                showMemory = true
            }
            defaults.set(showMemory, forKey: Keys.showMemory)
        }
    }
    @Published var showDisk: Bool {
        didSet {
            if !showCPU && !showMemory && !showDisk {
                showDisk = true
            }
            defaults.set(showDisk, forKey: Keys.showDisk)
        }
    }
    @Published var showNetwork: Bool {
        didSet { defaults.set(showNetwork, forKey: Keys.showNetwork) }
    }
    @Published var useThresholdColors: Bool {
        didSet { defaults.set(useThresholdColors, forKey: Keys.useThresholdColors) }
    }
    @Published var panelStyle: PanelStyle {
        didSet { defaults.set(panelStyle.rawValue, forKey: Keys.panelStyle) }
    }
    @Published var appearanceMode: AppearanceMode {
        didSet {
            defaults.set(appearanceMode.rawValue, forKey: Keys.appearanceMode)
            applyAppearance()
        }
    }
    @Published var loginItemError: String?

    private let defaults: UserDefaults
    private let appliesSystemAppearance: Bool

    init(defaults: UserDefaults = .standard, appliesSystemAppearance: Bool = true) {
        self.defaults = defaults
        self.appliesSystemAppearance = appliesSystemAppearance
        let storedShowCPU = defaults.object(forKey: Keys.showCPU) as? Bool ?? true
        let storedShowMemory = defaults.object(forKey: Keys.showMemory) as? Bool ?? true
        let storedShowDisk = defaults.object(forKey: Keys.showDisk) as? Bool ?? true
        let allMenuMetricsHidden = !storedShowCPU && !storedShowMemory && !storedShowDisk
        refreshIntervalStorage = Self.normalizedRefreshInterval(defaults.object(forKey: Keys.refreshInterval) as? Double ?? 2)
        showCPU = allMenuMetricsHidden ? true : storedShowCPU
        showMemory = storedShowMemory
        showDisk = storedShowDisk
        showNetwork = defaults.object(forKey: Keys.showNetwork) as? Bool ?? true
        useThresholdColors = defaults.object(forKey: Keys.useThresholdColors) as? Bool ?? true
        // Default to System Default (2×2 glass tiles) so first launch matches the UI preview.
        panelStyle = PanelStyle(rawValue: defaults.string(forKey: Keys.panelStyle) ?? "") ?? .controlCenter
        appearanceMode = AppearanceMode(rawValue: defaults.string(forKey: Keys.appearanceMode) ?? "") ?? .system
        if allMenuMetricsHidden {
            defaults.set(true, forKey: Keys.showCPU)
        }
        applyAppearance()
    }

    /// Applies the preferred light/dark/system mode to the whole app (panels + settings).
    func applyAppearance() {
        guard appliesSystemAppearance else { return }
        NSApp.appearance = appearanceMode.nsAppearance
    }

    var refreshInterval: Double {
        get { refreshIntervalStorage }
        set {
            let value = Self.normalizedRefreshInterval(newValue)
            refreshIntervalStorage = value
            defaults.set(value, forKey: Keys.refreshInterval)
        }
    }

    var refreshIntervalPublisher: Published<Double>.Publisher {
        $refreshIntervalStorage
    }

    var visibleMenuKinds: [MetricKind] {
        var kinds: [MetricKind] = []
        if showCPU { kinds.append(.cpu) }
        if showMemory { kinds.append(.memory) }
        if showDisk { kinds.append(.disk) }
        return kinds.isEmpty ? [.cpu] : kinds
    }

    func visibleMetrics(from snapshot: SystemSnapshot) -> [MetricSnapshot] {
        snapshot.metrics.filter { metric in
            switch metric.kind {
            case .cpu: showCPU
            case .memory: showMemory
            case .disk: showDisk
            case .network: false
            }
        }
    }

    private enum Keys {
        static let refreshInterval = "refreshInterval"
        static let showCPU = "showCPU"
        static let showMemory = "showMemory"
        static let showDisk = "showDisk"
        static let showNetwork = "showNetwork"
        static let useThresholdColors = "useThresholdColors"
        static let panelStyle = "panelStyle"
        static let appearanceMode = "appearanceMode"
    }

    private static func normalizedRefreshInterval(_ value: Double) -> Double {
        min(max(value, 1), 10)
    }
}

@MainActor
final class SystemMonitor: ObservableObject {
    @Published private(set) var snapshot = SystemSnapshot.placeholder
    @Published private(set) var history = MetricHistory.empty

    private let settings: AppSettings
    private let sampler = SystemSampler()
    private var timer: Timer?
    private var settingsCancellable: AnyCancellable?
    private let maxHistorySamples = 30

    init(settings: AppSettings) {
        self.settings = settings
        sampler.primeCPU()
        refresh()
        startTimer()
        settingsCancellable = settings.refreshIntervalPublisher.dropFirst().sink { [weak self] _ in
            self?.startTimer()
        }
    }

    deinit {
        timer?.invalidate()
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: settings.refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
        timer?.tolerance = min(0.5, settings.refreshInterval * 0.15)
    }

    func refresh() {
        let nextSnapshot = sampler.snapshot()
        snapshot = nextSnapshot
        history.append(nextSnapshot, maxCount: maxHistorySamples)
    }
}
