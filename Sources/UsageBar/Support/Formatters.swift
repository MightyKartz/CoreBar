import Foundation

extension Double {
    var percentText: String {
        "\(Int((clamped01 * 100).rounded()))%"
    }

    var clamped01: Double {
        min(max(self, 0), 1)
    }
}

extension UInt64 {
    var byteText: String {
        ByteCountFormatter.string(fromByteCount: Int64(self), countStyle: .file)
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
