import Foundation

enum HealthRules {
    static func level(for value: Double, warning: Double = 0.75, critical: Double = 0.9) -> HealthLevel {
        let value = value.clamped01

        if value >= critical {
            return .critical
        }

        if value >= warning {
            return .warning
        }

        return .normal
    }
}
