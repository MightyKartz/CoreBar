import Darwin
import Foundation

final class SystemSampler {
    private var previousCPUTicks: CPUTicks?

    func primeCPU() {
        previousCPUTicks = currentCPUTicks()
    }

    func snapshot() -> SystemSnapshot {
        let cpuUsage = sampleCPUUsage()
        let memory = sampleMemory()
        let disk = sampleDisk()

        return SystemSnapshot(
            cpu: MetricSnapshot(
                kind: .cpu,
                title: "CPU",
                symbol: "cpu",
                value: cpuUsage,
                detail: "System load over the last sample",
                level: HealthRules.level(for: cpuUsage),
                usedBytes: nil,
                totalBytes: nil,
                freeBytes: nil,
                coreCount: ProcessInfo.processInfo.processorCount
            ),
            memory: MetricSnapshot(
                kind: .memory,
                title: "Memory",
                symbol: "memorychip",
                value: memory.pressure,
                detail: "\(memory.used.byteText) active of \(memory.total.byteText)",
                level: HealthRules.level(for: memory.pressure),
                usedBytes: memory.used,
                totalBytes: memory.total,
                freeBytes: memory.total - memory.used,
                coreCount: nil
            ),
            disk: MetricSnapshot(
                kind: .disk,
                title: "Disk",
                symbol: "internaldrive",
                value: disk.usedFraction,
                detail: "\(disk.free.byteText) free of \(disk.total.byteText)",
                level: HealthRules.level(for: disk.usedFraction, warning: 0.85, critical: 0.95),
                usedBytes: disk.total - disk.free,
                totalBytes: disk.total,
                freeBytes: disk.free,
                coreCount: nil
            ),
            timestamp: .now
        )
    }

    private func sampleCPUUsage() -> Double {
        guard let current = currentCPUTicks() else {
            return 0
        }

        defer {
            previousCPUTicks = current
        }

        guard let previous = previousCPUTicks else {
            return 0
        }

        let total = current.total - previous.total
        guard total > 0 else {
            return 0
        }

        let idle = current.idle - previous.idle
        return (Double(total - idle) / Double(total)).clamped01
    }

    private func currentCPUTicks() -> CPUTicks? {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return nil
        }

        return CPUTicks(
            user: UInt64(info.cpu_ticks.0),
            system: UInt64(info.cpu_ticks.1),
            idle: UInt64(info.cpu_ticks.2),
            nice: UInt64(info.cpu_ticks.3)
        )
    }

    private func sampleMemory() -> MemoryReading {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            let total = ProcessInfo.processInfo.physicalMemory
            return MemoryReading(used: 0, total: total, pressure: 0)
        }

        var pageSize = vm_size_t()
        host_page_size(mach_host_self(), &pageSize)

        let pageBytes = UInt64(pageSize)
        let total = ProcessInfo.processInfo.physicalMemory
        let active = UInt64(stats.active_count) * pageBytes
        let wired = UInt64(stats.wire_count) * pageBytes
        let compressed = UInt64(stats.compressor_page_count) * pageBytes
        let used = min(total, active + wired + compressed)

        // ponytail: approximates Activity Monitor pressure with public vm stats; replace if Apple exposes a direct API.
        let releasablePages = UInt64(stats.free_count + stats.inactive_count + stats.speculative_count + stats.purgeable_count + stats.compressor_page_count)
        let releasable = min(total, releasablePages * pageBytes)
        let pressure = (1 - (Double(releasable) / Double(total))).clamped01

        return MemoryReading(used: used, total: total, pressure: pressure)
    }

    private func sampleDisk() -> DiskReading {
        do {
            let attributes = try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
            let total = (attributes[.systemSize] as? NSNumber)?.uint64Value ?? 0
            let free = (attributes[.systemFreeSize] as? NSNumber)?.uint64Value ?? 0

            guard total > 0 else {
                return DiskReading(free: 0, total: 0)
            }

            return DiskReading(free: free, total: total)
        } catch {
            return DiskReading(free: 0, total: 0)
        }
    }
}

private struct CPUTicks {
    let user: UInt64
    let system: UInt64
    let idle: UInt64
    let nice: UInt64

    var total: UInt64 {
        user + system + idle + nice
    }
}

private struct MemoryReading {
    let used: UInt64
    let total: UInt64
    let pressure: Double
}

private struct DiskReading {
    let free: UInt64
    let total: UInt64

    var usedFraction: Double {
        guard total > 0 else {
            return 0
        }

        return (Double(total - free) / Double(total)).clamped01
    }
}
