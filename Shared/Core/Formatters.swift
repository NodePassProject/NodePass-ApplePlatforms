//
//  Formatters.swift
//  NodePass
//
//  Human-readable formatting for bytes, rates, durations and percentages.
//

import Foundation

nonisolated enum Format {
    private static let byteUnits = ["B", "KB", "MB", "GB", "TB", "PB", "EB"]
    private static let bitUnits = ["bps", "Kbps", "Mbps", "Gbps", "Tbps"]

    /// Formats a byte count using 1024-based units, e.g. `1.50 GB`.
    static func bytes(_ value: UInt64, decimals: Int = 2) -> String {
        var amount = Double(value)
        var index = 0
        while amount >= 1024, index < byteUnits.count - 1 {
            amount /= 1024
            index += 1
        }
        let digits = index == 0 ? 0 : decimals
        return "\(amount.formatted(.number.precision(.fractionLength(0...digits)))) \(byteUnits[index])"
    }

    static func bytes(_ value: Int64, decimals: Int = 2) -> String {
        bytes(UInt64(max(0, value)), decimals: decimals)
    }

    /// Formats a throughput given in bytes per second as a bit rate, e.g. `12.3 Mbps`.
    static func bitRate(bytesPerSecond: Double) -> String {
        var amount = max(0, bytesPerSecond) * 8
        var index = 0
        while amount >= 1000, index < bitUnits.count - 1 {
            amount /= 1000
            index += 1
        }
        let digits = index == 0 ? 0 : 1
        return "\(amount.formatted(.number.precision(.fractionLength(0...digits)))) \(bitUnits[index])"
    }

    /// Formats a throughput given in bytes per second as bytes, e.g. `1.2 MB/s`.
    static func byteRate(bytesPerSecond: Double) -> String {
        bytes(UInt64(max(0, bytesPerSecond)), decimals: 1) + "/s"
    }

    /// Formats a duration in seconds as `3d 4h`, `4h 12m`, `12m 3s` or `45s`.
    static func duration(seconds: UInt64, compact: Bool = false) -> String {
        let minutes = seconds / 60
        let hours = minutes / 60
        let days = hours / 24

        if days >= 10 || (compact && days > 0) {
            return "\(days)d"
        }
        if days > 0 {
            return "\(days)d \(hours % 24)h"
        }
        if hours > 0 {
            return compact ? "\(hours)h" : "\(hours)h \(minutes % 60)m"
        }
        if minutes > 0 {
            return compact ? "\(minutes)m" : "\(minutes)m \(seconds % 60)s"
        }
        return "\(seconds)s"
    }

    static func duration(seconds: Int64, compact: Bool = false) -> String {
        duration(seconds: UInt64(max(0, seconds)), compact: compact)
    }

    /// Formats a 0...1 ratio as a percentage without decimals.
    static func percent(_ ratio: Double) -> String {
        let clamped = min(max(ratio, 0), 1)
        return clamped.formatted(.percent.precision(.fractionLength(0)))
    }

    /// Formats a latency in milliseconds.
    static func latency(milliseconds: Int) -> String {
        "\(milliseconds) ms"
    }

    /// Returns a short relative description such as "3 s ago".
    static func relative(_ date: Date, to reference: Date = .now) -> String {
        let interval = reference.timeIntervalSince(date)
        if interval < 1 { return "just now" }
        if interval < 60 { return "\(Int(interval)) s ago" }
        if interval < 3600 { return "\(Int(interval / 60)) min ago" }
        if interval < 86400 { return "\(Int(interval / 3600)) h ago" }
        return "\(Int(interval / 86400)) d ago"
    }
}
