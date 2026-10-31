//
//  LogBuffer.swift
//  NodePass
//
//  Bounded, append-only buffer of log lines received through SSE `log` events.
//

import Foundation

struct LogLine: Hashable, Identifiable {
    enum Level: String, CaseIterable, Hashable {
        case debug, info, warn, error, event, unknown

        var title: String { rawValue.uppercased() }
    }

    let id: UUID
    let date: Date
    let text: String
    let level: Level

    init(date: Date = .now, rawText: String) {
        self.id = UUID()
        self.date = date
        let cleaned = LogLine.stripANSI(rawText).trimmingCharacters(in: .whitespacesAndNewlines)
        self.text = cleaned
        self.level = LogLine.detectLevel(in: cleaned)
    }

    /// Removes ANSI SGR escape sequences such as `\u{1B}[32m`.
    static func stripANSI(_ text: String) -> String {
        var result = ""
        result.reserveCapacity(text.count)
        var iterator = text.makeIterator()
        while let character = iterator.next() {
            if character == "\u{1B}" {
                // Skip until a letter terminates the sequence.
                while let next = iterator.next(), !next.isLetter {}
                continue
            }
            result.append(character)
        }
        return result
    }

    static func detectLevel(in text: String) -> Level {
        let upper = text.uppercased()
        for level in [Level.error, .warn, .debug, .event, .info] {
            if upper.contains(" \(level.title) ") || upper.hasPrefix(level.title) || upper.contains("[\(level.title)]") {
                return level
            }
        }
        if upper.contains("ERROR:") { return .error }
        return .unknown
    }
}

struct LogBuffer {
    private(set) var lines: [LogLine] = []
    var capacity: Int

    init(capacity: Int) {
        self.capacity = max(50, capacity)
    }

    mutating func append(_ line: LogLine) {
        lines.append(line)
        if lines.count > capacity {
            lines.removeFirst(lines.count - capacity)
        }
    }

    mutating func clear() {
        lines.removeAll()
    }

    var isEmpty: Bool { lines.isEmpty }
    var count: Int { lines.count }

    /// Plain-text export.
    var exportText: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return lines.map { "\(formatter.string(from: $0.date)) \($0.text)" }.joined(separator: "\n")
    }
}
