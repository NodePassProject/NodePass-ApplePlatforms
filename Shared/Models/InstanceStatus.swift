//
//  InstanceStatus.swift
//  NodePass
//

import Foundation

nonisolated enum InstanceStatus: Hashable, Sendable, Codable, Comparable {
    case running
    case stopped
    case error
    case other(String)

    init(rawValue: String) {
        switch rawValue.lowercased() {
        case "running": self = .running
        case "stopped": self = .stopped
        case "error": self = .error
        default: self = .other(rawValue)
        }
    }

    var rawValue: String {
        switch self {
        case .running: "running"
        case .stopped: "stopped"
        case .error: "error"
        case .other(let value): value
        }
    }

    var title: String {
        switch self {
        case .running: "Running"
        case .stopped: "Stopped"
        case .error: "Error"
        case .other(let value): value.isEmpty ? "Unknown" : value.capitalized
        }
    }

    var symbolName: String {
        switch self {
        case .running: "play.circle.fill"
        case .stopped: "stop.circle.fill"
        case .error: "exclamationmark.triangle.fill"
        case .other: "questionmark.circle.fill"
        }
    }

    /// Ordering used when sorting by status: errors first, then running, then stopped.
    private var sortRank: Int {
        switch self {
        case .error: 0
        case .running: 1
        case .stopped: 2
        case .other: 3
        }
    }

    static func < (lhs: InstanceStatus, rhs: InstanceStatus) -> Bool {
        lhs.sortRank < rhs.sortRank
    }

    static let knownStatuses: [InstanceStatus] = [.running, .stopped, .error]

    // MARK: Codable

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.init(rawValue: try container.decode(String.self))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
