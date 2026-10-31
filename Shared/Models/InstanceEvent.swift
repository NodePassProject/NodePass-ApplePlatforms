//
//  InstanceEvent.swift
//  NodePass
//
//  Payload of the `event: instance` Server-Sent Events emitted by `/events`.
//

import Foundation

nonisolated struct InstanceEvent: Sendable, Hashable {
    nonisolated enum Kind: Hashable, Sendable {
        case initial
        case create
        case update
        case delete
        case log
        case shutdown
        case other(String)

        init(rawValue: String) {
            switch rawValue.lowercased() {
            case "initial": self = .initial
            case "create": self = .create
            case "update": self = .update
            case "delete": self = .delete
            case "log": self = .log
            case "shutdown": self = .shutdown
            default: self = .other(rawValue)
            }
        }
    }

    var kind: Kind
    var time: Date
    var instance: Instance?
    var logs: String

    init(kind: Kind, time: Date = .now, instance: Instance? = nil, logs: String = "") {
        self.kind = kind
        self.time = time
        self.instance = instance
        self.logs = logs
    }
}

extension InstanceEvent: Decodable {
    private enum CodingKeys: String, CodingKey {
        case type, time, instance, logs
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        kind = Kind(rawValue: try container.decodeIfPresent(String.self, forKey: .type) ?? "")
        let rawTime = try container.decodeIfPresent(String.self, forKey: .time)
        time = rawTime.flatMap(RFC3339.parse) ?? .now
        instance = try container.decodeIfPresent(Instance.self, forKey: .instance)
        logs = try container.decodeIfPresent(String.self, forKey: .logs) ?? ""
    }
}

/// Lenient RFC 3339 parsing. Go emits nanosecond fractions and numeric offsets, which
/// `ISO8601DateFormatter` only accepts with exactly three fractional digits.
nonisolated enum RFC3339 {
    static func parse(_ string: String) -> Date? {
        let normalized = normalizeFraction(string)
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFraction.date(from: normalized) { return date }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: normalized)
    }

    /// Truncates or removes the fractional-seconds component so it has exactly three digits (or none).
    private static func normalizeFraction(_ string: String) -> String {
        guard let dot = string.firstIndex(of: ".") else { return string }
        var end = string.index(after: dot)
        while end < string.endIndex, string[end].isNumber { end = string.index(after: end) }
        let fraction = string[string.index(after: dot)..<end]
        let suffix = string[end...]
        if fraction.isEmpty { return String(string[..<dot]) + suffix }
        let padded = String(fraction.prefix(3)).padding(toLength: 3, withPad: "0", startingAt: 0)
        return String(string[..<dot]) + "." + padded + suffix
    }
}
