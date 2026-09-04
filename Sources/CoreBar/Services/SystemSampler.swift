import Darwin
import Foundation

final class SystemSampler {
    private let diskRefreshInterval: TimeInterval
    private let diskReader: () -> DiskReading
    private let networkReader: () -> NetworkCounters
    private var previousCPUTicks: CPUTicks?
    private var cachedDisk: DiskReading?
    private var lastDiskSampleAt: Date?
    private var previousNetworkCounters: NetworkCounters?
    private var previousNetworkSampleAt: Date?

    init(
        diskRefreshInterval: TimeInterval = 60,
        diskReader: @escaping () -> DiskReading = SystemSampler.readDisk,
        networkReader: @escaping () -> NetworkCounters = SystemSampler.readNetworkCounters
    ) {
        self.diskRefreshInterval = diskRefreshInterval
        self.diskReader = diskReader
        self.networkReader = networkReader
    }

    func primeCPU() {
        previousCPUTicks = currentCPUTicks()
    }

    func snapshot(now: Date = .now) -> SystemSnapshot {
        let cpuUsage = sampleCPUUsage()
        let memory = sampleMemory()
        let disk = sampleDisk(now: now)
        let network = sampleNetwork(now: now)

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
                detail: "\(memory.used.memoryByteText) active of \(memory.total.memoryByteText)",
                level: HealthRules.level(for: memory.pressure),
                usedBytes: memory.used,
                totalBytes: memory.total,
                freeBytes: memory.total > memory.used ? memory.total - memory.used : 0,
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
            network: network,
            timestamp: now
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
        let pressure = total > 0 ? (1 - (Double(releasable) / Double(total))).clamped01 : 0

        return MemoryReading(used: used, total: total, pressure: pressure)
    }

    private func sampleDisk(now: Date) -> DiskReading {
        if let cachedDisk, let lastDiskSampleAt, now.timeIntervalSince(lastDiskSampleAt) < diskRefreshInterval {
            return cachedDisk
        }

        let disk = diskReader()
        cachedDisk = disk
        lastDiskSampleAt = now
        return disk
    }

    private static func readDisk() -> DiskReading {
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

    private func sampleNetwork(now: Date) -> NetworkSnapshot {
        let counters = networkReader()

        defer {
            previousNetworkCounters = counters
            previousNetworkSampleAt = now
        }

        guard let previousNetworkCounters, let previousNetworkSampleAt else {
            return .zero
        }

        let elapsed = now.timeIntervalSince(previousNetworkSampleAt)
        guard elapsed > 0 else {
            return .zero
        }

        let receivedDelta = counters.receivedBytes >= previousNetworkCounters.receivedBytes
            ? counters.receivedBytes - previousNetworkCounters.receivedBytes
            : 0
        let transmittedDelta = counters.transmittedBytes >= previousNetworkCounters.transmittedBytes
            ? counters.transmittedBytes - previousNetworkCounters.transmittedBytes
            : 0

        return NetworkSnapshot(
            downloadBytesPerSecond: Double(receivedDelta) / elapsed,
            uploadBytesPerSecond: Double(transmittedDelta) / elapsed
        )
    }

    private static func readNetworkCounters() -> NetworkCounters {
        var interfaces: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&interfaces) == 0, let firstInterface = interfaces else {
            return .zero
        }

        defer {
            freeifaddrs(interfaces)
        }

        var counters = NetworkCounters.zero
        var pointer: UnsafeMutablePointer<ifaddrs>? = firstInterface

        while let current = pointer {
            defer {
                pointer = current.pointee.ifa_next
            }

            let interface = current.pointee
            let flags = Int32(interface.ifa_flags)
            guard
                flags & IFF_UP != 0,
                flags & IFF_LOOPBACK == 0,
                let address = interface.ifa_addr,
                address.pointee.sa_family == UInt8(AF_LINK),
                let data = interface.ifa_data
            else {
                continue
            }

            let networkData = data.assumingMemoryBound(to: if_data.self).pointee
            counters.receivedBytes += UInt64(networkData.ifi_ibytes)
            counters.transmittedBytes += UInt64(networkData.ifi_obytes)
        }

        return counters
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

struct DiskReading {
    let free: UInt64
    let total: UInt64

    var usedFraction: Double {
        guard total > 0 else {
            return 0
        }

        return (Double(total - free) / Double(total)).clamped01
    }
}

struct NetworkCounters {
    var receivedBytes: UInt64
    var transmittedBytes: UInt64

    static let zero = NetworkCounters(receivedBytes: 0, transmittedBytes: 0)
}
