import Foundation

enum MetricKind: String {
    case cpu
    case memory
    case disk

    var index: Int {
        switch self {
        case .cpu: 0
        case .memory: 1
        case .disk: 2
        }
    }
}

struct MetricSnapshot: Identifiable {
    let kind: MetricKind
    let title: String
    let symbol: String
    let value: Double
    let detail: String
    let level: HealthLevel
    let usedBytes: UInt64?
    let totalBytes: UInt64?
    let freeBytes: UInt64?
    let coreCount: Int?

    var id: MetricKind { kind }
}

struct SystemSnapshot {
    let cpu: MetricSnapshot
    let memory: MetricSnapshot
    let disk: MetricSnapshot
    let timestamp: Date

    var metrics: [MetricSnapshot] {
        [cpu, memory, disk]
    }

    var headlineMetric: MetricSnapshot {
        metrics.max {
            ($0.level.rawValue, $0.value) < ($1.level.rawValue, $1.value)
        } ?? cpu
    }

    var overallLevel: HealthLevel {
        headlineMetric.level
    }

    var menuPercentText: String {
        headlineMetric.value.percentText
    }

    static let placeholder = SystemSnapshot(
        cpu: MetricSnapshot(
            kind: .cpu,
            title: "CPU",
            symbol: "cpu",
            value: 0,
            detail: "Waiting for first sample",
            level: .normal,
            usedBytes: nil,
            totalBytes: nil,
            freeBytes: nil,
            coreCount: nil
        ),
        memory: MetricSnapshot(
            kind: .memory,
            title: "Memory",
            symbol: "memorychip",
            value: 0,
            detail: "Waiting for first sample",
            level: .normal,
            usedBytes: nil,
            totalBytes: nil,
            freeBytes: nil,
            coreCount: nil
        ),
        disk: MetricSnapshot(
            kind: .disk,
            title: "Disk",
            symbol: "internaldrive",
            value: 0,
            detail: "Waiting for first sample",
            level: .normal,
            usedBytes: nil,
            totalBytes: nil,
            freeBytes: nil,
            coreCount: nil
        ),
        timestamp: .now
    )
}

struct MetricHistory {
    private(set) var cpu: [Double]
    private(set) var memory: [Double]
    private(set) var disk: [Double]

    static let empty = MetricHistory(cpu: [], memory: [], disk: [])

    mutating func append(_ snapshot: SystemSnapshot, maxCount: Int) {
        append(snapshot.cpu.value, to: &cpu, maxCount: maxCount)
        append(snapshot.memory.value, to: &memory, maxCount: maxCount)
        append(snapshot.disk.value, to: &disk, maxCount: maxCount)
    }

    func values(for kind: MetricKind) -> [Double] {
        switch kind {
        case .cpu: cpu
        case .memory: memory
        case .disk: disk
        }
    }

    private func append(_ value: Double, to values: inout [Double], maxCount: Int) {
        values.append(value.clamped01)

        if values.count > maxCount {
            values.removeFirst(values.count - maxCount)
        }
    }
}
