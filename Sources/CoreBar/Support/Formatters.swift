import Foundation

extension Double {
    var percentText: String {
        "\(Int((clamped01 * 100).rounded()))%"
    }

    var byteRateText: String {
        guard isFinite, self > 0 else {
            return "0 B/s"
        }

        return "\(ByteCountFormatter.string(fromByteCount: Int64(rounded()), countStyle: .file))/s"
    }

    var clamped01: Double {
        min(max(self, 0), 1)
    }
}

extension UInt64 {
    /// Disk / file sizes (decimal units, e.g. 500.07 GB).
    var byteText: String {
        ByteCountFormatter.string(fromByteCount: Int64(self), countStyle: .file)
    }

    /// Physical RAM sizes (binary units so 16 GiB shows as "16 GB", not "17.18 GB").
    var memoryByteText: String {
        ByteCountFormatter.string(fromByteCount: Int64(self), countStyle: .memory)
    }
}

extension Date {
    var shortTimeText: String {
        Self.timeFormatter.string(from: self)
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        formatter.dateStyle = .none
        return formatter
    }()
}
