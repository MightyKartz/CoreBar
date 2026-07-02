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
        }
    }

    static var normal: String { choose(en: "Healthy", zh: "正常") }
    static var warning: String { choose(en: "Watch", zh: "注意") }
    static var critical: String { choose(en: "Critical", zh: "严重") }
    static var normalShort: String { choose(en: "OK", zh: "正常") }
    static var warningShort: String { choose(en: "WARN", zh: "注意") }
    static var criticalShort: String { choose(en: "HOT", zh: "严重") }
    static var usage: String { choose(en: "Usage", zh: "用量") }
    static var updated: String { choose(en: "Updated", zh: "更新于") }
    static var refresh: String { choose(en: "Refresh", zh: "刷新") }
    static var activityMonitor: String { choose(en: "Activity Monitor", zh: "活动监视器") }
    static var quit: String { choose(en: "Quit", zh: "退出") }
    static var used: String { choose(en: "Used", zh: "已用") }
    static var free: String { choose(en: "Free", zh: "剩余") }
    static var pressure: String { choose(en: "Pressure", zh: "压力") }
    static var cores: String { choose(en: "cores", zh: "核心") }
    static var currentLoad: String { choose(en: "Current load", zh: "当前负载") }
    static var waiting: String { choose(en: "Waiting for first sample", zh: "等待首次采样") }

    private static func choose(en: String, zh: String) -> String {
        isChinese ? zh : en
    }
}
