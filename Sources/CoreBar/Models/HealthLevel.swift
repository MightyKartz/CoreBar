import SwiftUI

enum HealthLevel: Int, Comparable {
    case normal
    case warning
    case critical

    static func < (lhs: HealthLevel, rhs: HealthLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var title: String {
        switch self {
        case .normal: AppText.normal
        case .warning: AppText.warning
        case .critical: AppText.critical
        }
    }

    var shortTitle: String {
        switch self {
        case .normal: AppText.normalShort
        case .warning: AppText.warningShort
        case .critical: AppText.criticalShort
        }
    }

    var symbol: String {
        switch self {
        case .normal: "circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .critical: "exclamationmark.triangle.fill"
        }
    }

    var color: Color {
        switch self {
        case .normal: .green
        case .warning: .yellow
        case .critical: .red
        }
    }

    var nsColor: NSColor {
        switch self {
        case .normal: .systemGreen
        case .warning: .systemYellow
        case .critical: .systemRed
        }
    }
}
