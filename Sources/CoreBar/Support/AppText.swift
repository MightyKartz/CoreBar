import Foundation

enum AppText {
    static var isChinese: Bool {
        isChinese(localeIdentifier: Locale.autoupdatingCurrent.identifier, preferredLanguages: Locale.preferredLanguages)
    }

    static func isChinese(localeIdentifier: String, preferredLanguages: [String]) -> Bool {
        ([localeIdentifier] + preferredLanguages).contains {
            $0.lowercased().hasPrefix("zh")
        }
    }

    static func metricTitle(_ kind: MetricKind) -> String {
        switch kind {
        case .cpu: "CPU"
        case .memory: choose(en: "Memory", zh: "内存")
        case .disk: choose(en: "Disk", zh: "磁盘")
        case .network: choose(en: "Network", zh: "网络")
        }
    }

    static var normal: String { choose(en: "Healthy", zh: "正常") }
    static var warning: String { choose(en: "Watch", zh: "注意") }
    static var critical: String { choose(en: "Critical", zh: "严重") }
    static var normalShort: String { choose(en: "OK", zh: "正常") }
    static var warningShort: String { choose(en: "WARN", zh: "注意") }
    static var criticalShort: String { choose(en: "HOT", zh: "严重") }
    /// Compact health pill copy used in panel headers (matches UI preview).
    static var healthPillNormal: String { choose(en: "OK", zh: "良好") }
    static var healthPillWarning: String { choose(en: "Watch", zh: "注意") }
    static var healthPillCritical: String { choose(en: "Hot", zh: "严重") }
    static var usage: String { choose(en: "Usage", zh: "用量") }
    static var updated: String { choose(en: "Updated", zh: "更新于") }
    static var live: String { choose(en: "Live", zh: "实时") }
    static var refresh: String { choose(en: "Refresh", zh: "刷新") }
    static var activityMonitor: String { choose(en: "Activity Monitor", zh: "活动监视器") }
    static var openCoreBar: String { choose(en: "Open CoreBar", zh: "打开 CoreBar") }
    static var quit: String { choose(en: "Quit", zh: "退出") }
    static var quitCoreBar: String { choose(en: "Quit CoreBar", zh: "退出 CoreBar") }
    static var used: String { choose(en: "Used", zh: "已用") }
    static var free: String { choose(en: "Free", zh: "剩余") }
    static var pressure: String { choose(en: "Pressure", zh: "压力") }
    static var cores: String { choose(en: "cores", zh: "核心") }
    static var currentLoad: String { choose(en: "Current load", zh: "当前负载") }
    static var waiting: String { choose(en: "Waiting for first sample", zh: "等待首次采样") }
    static var general: String { choose(en: "General", zh: "通用") }
    static var launchAtLogin: String { choose(en: "Launch at login", zh: "开机启动") }
    static var refreshInterval: String { choose(en: "Refresh interval", zh: "刷新频率") }
    static var visibleMetrics: String { choose(en: "Visible metrics", zh: "显示指标") }
    static var networkPanelOnly: String { choose(en: "Network (panel only)", zh: "网络（仅面板）") }
    static var appearance: String { choose(en: "Appearance", zh: "外观") }
    static var colorScheme: String { choose(en: "Color scheme", zh: "外观模式") }
    static var appearanceSystem: String { choose(en: "Auto", zh: "系统") }
    static var appearanceLight: String { choose(en: "Light", zh: "浅色") }
    static var appearanceDark: String { choose(en: "Dark", zh: "深色") }
    static var thresholdColors: String { choose(en: "Threshold colors", zh: "阈值颜色") }
    static var panelStyle: String { choose(en: "Panel style", zh: "面板风格") }
    static var classicPanel: String { choose(en: "Classic", zh: "经典") }
    static var controlCenterPanel: String { choose(en: "System Default", zh: "系统默认") }
    static var download: String { choose(en: "Down", zh: "下载") }
    static var upload: String { choose(en: "Up", zh: "上传") }
    static var settings: String { choose(en: "Settings", zh: "设置") }
    static var about: String { choose(en: "About", zh: "关于") }
    static var aboutCoreBar: String { choose(en: "About CoreBar", zh: "关于 CoreBar") }
    static var privacyPolicy: String { choose(en: "Privacy Policy", zh: "隐私政策") }
    static var getSupport: String { choose(en: "Get Support", zh: "获取支持") }
    static var close: String { choose(en: "Close", zh: "关闭") }
    static var version: String { choose(en: "Version", zh: "版本") }
    static var localOnlyDescription: String {
        choose(
            en: "System usage data is processed locally and never leaves this Mac.",
            zh: "系统用量数据仅在本机处理，不会离开这台 Mac。"
        )
    }
    static var noMetrics: String { choose(en: "No visible metrics", zh: "没有显示指标") }
    static var recentHistory: String { choose(en: "Recent history", zh: "近期历史") }
    static var thresholdColorsHint: String {
        choose(en: "Warn at 75% / critical at 90%", zh: "超过 75% / 90% 显示警示色")
    }

    static func seconds(_ value: Double) -> String {
        choose(en: "\(Int(value))s", zh: "\(Int(value)) 秒")
    }

    static func healthPillTitle(_ level: HealthLevel) -> String {
        switch level {
        case .normal: healthPillNormal
        case .warning: healthPillWarning
        case .critical: healthPillCritical
        }
    }

    /// Normal operation stays intentionally quiet; warning and critical states
    /// progressively expose the metric that needs attention.
    static func healthPillFullTitle(
        _ level: HealthLevel,
        metricTitle: String,
        percent: Double
    ) -> String {
        guard level != .normal else { return healthPillTitle(level) }
        return "\(healthPillTitle(level)) · \(metricTitle) \(percent.percentText)"
    }

    static func healthPillCompactTitle(
        _ level: HealthLevel,
        metricTitle: String,
        percent: Double
    ) -> String {
        guard level != .normal else { return healthPillTitle(level) }
        return "\(metricTitle) \(percent.percentText)"
    }

    static func healthPillMinimalTitle(_ level: HealthLevel, percent: Double) -> String {
        level == .normal ? healthPillTitle(level) : percent.percentText
    }

    static func choose(en: String, zh: String) -> String {
        isChinese ? zh : en
    }

    /// Testable copy selection without relying on live locale.
    static func choose(en: String, zh: String, isChinese: Bool) -> String {
        isChinese ? zh : en
    }
}

enum AppLinks {
    static let privacyPolicy = URL(string: "https://github.com/MightyKartz/CoreBar/blob/main/PRIVACY.md")!
    static let support = URL(string: "https://github.com/MightyKartz/CoreBar/issues")!
}
