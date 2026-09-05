import Darwin
import Foundation

final class SystemSampler {
    private let diskRefreshInterval: TimeInterval
    private let diskReader: () -> DiskReading
    private let networkReader: () -> NetworkInterfaceCounters?
    private let monotonicClock: () -> TimeInterval
    private var previousCPUTicks: CPUTicks?
    private var cachedDisk: DiskReading?
    private var lastDiskSampleAt: TimeInterval?
    private var previousNetworkCounters: NetworkInterfaceCounters?
    private var previousNetworkSampleAt: TimeInterval?

    init(
        diskRefreshInterval: TimeInterval = 60,
        diskReader: @escaping () -> DiskReading = SystemSampler.readDisk,
        networkReader: @escaping () -> NetworkInterfaceCounters? = SystemSampler.readNetworkCounters,
        monotonicClock: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
    ) {
        self.diskRefreshInterval = diskRefreshInterval
        self.diskReader = diskReader
        self.networkReader = networkReader
        self.monotonicClock = monotonicClock
    }

    func primeCPU() {
        previousCPUTicks = currentCPUTicks()
    }

    func snapshot(now: Date = .now) -> SystemSnapshot {
        let sampleTime = monotonicClock()
        let cpuUsage = sampleCPUUsage()
        let memory = sampleMemory()
        let disk = sampleDisk(at: sampleTime)
        let network = sampleNetwork(at: sampleTime)

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

        return current.usage(since: previous)
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
            user: info.cpu_ticks.0,
            system: info.cpu_ticks.1,
            idle: info.cpu_ticks.2,
            nice: info.cpu_ticks.3
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
        guard host_page_size(mach_host_self(), &pageSize) == KERN_SUCCESS, pageSize > 0 else {
            return MemoryReading(used: 0, total: ProcessInfo.processInfo.physicalMemory, pressure: 0)
        }

        return Self.memoryReading(stats: stats, pageBytes: UInt64(pageSize), total: ProcessInfo.processInfo.physicalMemory)
    }

    static func memoryReading(stats: vm_statistics64, pageBytes: UInt64, total: UInt64) -> MemoryReading {
        let usedPages = UInt64(stats.active_count) + UInt64(stats.wire_count) + UInt64(stats.compressor_page_count)
        let used = min(total, usedPages * pageBytes)

        // This remains a local estimate, not Activity Monitor's memory-pressure signal.
        // Darwin includes speculative_count in free_count, so do not add it again.
        let releasablePages = UInt64(stats.free_count) + UInt64(stats.inactive_count)
            + UInt64(stats.purgeable_count) + UInt64(stats.compressor_page_count)
        let releasable = min(total, releasablePages * pageBytes)
        let pressure = total > 0 ? (1 - (Double(releasable) / Double(total))).clamped01 : 0

        return MemoryReading(used: used, total: total, pressure: pressure)
    }

    private func sampleDisk(at sampleTime: TimeInterval) -> DiskReading {
        if let cachedDisk, let lastDiskSampleAt,
           sampleTime >= lastDiskSampleAt, sampleTime - lastDiskSampleAt < diskRefreshInterval {
            return cachedDisk
        }

        let disk = diskReader()
        cachedDisk = disk
        lastDiskSampleAt = sampleTime
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

    private func sampleNetwork(at sampleTime: TimeInterval) -> NetworkSnapshot {
        // A failed read must not replace a valid baseline with all-zero counters.
        guard let counters = networkReader() else { return .zero }

        defer {
            previousNetworkCounters = counters
            previousNetworkSampleAt = sampleTime
        }

        guard let previousNetworkCounters, let previousNetworkSampleAt else {
            return .zero
        }

        let elapsed = sampleTime - previousNetworkSampleAt
        guard elapsed.isFinite, elapsed > 0 else {
            return .zero
        }

        var receivedDelta = 0.0
        var transmittedDelta = 0.0
        for (index, current) in counters {
            // Newly active interfaces first establish their own baseline. Removed
            // interfaces disappear without subtracting their lifetime totals.
            guard let previous = previousNetworkCounters[index] else { continue }
            if current.receivedBytes >= previous.receivedBytes {
                receivedDelta += Double(current.receivedBytes - previous.receivedBytes)
            }
            if current.transmittedBytes >= previous.transmittedBytes {
                transmittedDelta += Double(current.transmittedBytes - previous.transmittedBytes)
            }
        }

        return NetworkSnapshot(
            downloadBytesPerSecond: receivedDelta / elapsed,
            uploadBytesPerSecond: transmittedDelta / elapsed
        )
    }

    private static func readNetworkCounters() -> NetworkInterfaceCounters? {
        // getifaddrs exposes 32-bit if_data byte counters. NET_RT_IFLIST2 returns
        // if_msghdr2/if_data64, preserving totals above 4 GiB on each interface.
        var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0]
        for _ in 0..<3 {
            var length = 0
            guard sysctl(&mib, u_int(mib.count), nil, &length, nil, 0) == 0 else { return nil }
            guard length > 0 else { return [:] }

            var buffer = [UInt8](repeating: 0, count: length)
            let result = buffer.withUnsafeMutableBytes {
                sysctl(&mib, u_int(mib.count), $0.baseAddress, &length, nil, 0)
            }
            guard result == 0 else {
                if errno == ENOMEM { continue } // Interface list grew between reads.
                return nil
            }
            guard length <= buffer.count else { return nil }

            return buffer.withUnsafeBytes { bytes in
                var counters: NetworkInterfaceCounters = [:]
                var offset = 0
                while offset < length {
                    guard length - offset >= 4 else { return nil }
                    let messageLength = Int(bytes.loadUnaligned(fromByteOffset: offset, as: UInt16.self))
                    guard messageLength >= 4, messageLength <= length - offset else { return nil }
                    let messageType = bytes.load(fromByteOffset: offset + 3, as: UInt8.self)
                    if messageType == RTM_IFINFO2 {
                        guard messageLength >= MemoryLayout<if_msghdr2>.size else { return nil }
                        let interface = bytes.loadUnaligned(fromByteOffset: offset, as: if_msghdr2.self)
                        if interface.ifm_flags & IFF_UP != 0, interface.ifm_flags & IFF_LOOPBACK == 0 {
                            counters[interface.ifm_index] = NetworkCounters(
                                receivedBytes: interface.ifm_data.ifi_ibytes,
                                transmittedBytes: interface.ifm_data.ifi_obytes
                            )
                        }
                    }
                    offset += messageLength
                }
                return counters
            }
        }
        return nil
    }
}

struct CPUTicks {
    // HOST_CPU_LOAD_INFO defines each state as a 32-bit natural_t counter.
    let user: UInt32
    let system: UInt32
    let idle: UInt32
    let nice: UInt32

    func usage(since previous: CPUTicks) -> Double {
        let busy = UInt64(user &- previous.user) + UInt64(system &- previous.system)
            + UInt64(nice &- previous.nice)
        let total = busy + UInt64(idle &- previous.idle)
        return total > 0 ? (Double(busy) / Double(total)).clamped01 : 0
    }
}

struct MemoryReading {
    let used: UInt64
    let total: UInt64
    let pressure: Double
}

struct DiskReading {
    let free: UInt64
    let total: UInt64

    init(free: UInt64, total: UInt64) {
        self.free = min(free, total)
        self.total = total
    }

    var usedFraction: Double {
        guard total > 0 else {
            return 0
        }

        return (Double(total - free) / Double(total)).clamped01
    }
}

struct NetworkCounters {
    let receivedBytes: UInt64
    let transmittedBytes: UInt64
}

typealias NetworkInterfaceCounters = [UInt16: NetworkCounters]
