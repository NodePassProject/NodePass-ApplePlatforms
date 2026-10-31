//
//  InstanceAction.swift
//  NodePass
//
//  Control actions accepted by `PATCH /instances/{id}` (`{"action": …}`).
//

import Foundation

nonisolated enum InstanceAction: String, CaseIterable, Hashable, Sendable, Identifiable {
    case start
    case stop
    case restart
    /// Clears the cumulative traffic counters.
    case reset

    var id: String { rawValue }

    var title: String {
        switch self {
        case .start: "Start"
        case .stop: "Stop"
        case .restart: "Restart"
        case .reset: "Reset Traffic"
        }
    }

    var symbolName: String {
        switch self {
        case .start: "play.fill"
        case .stop: "stop.fill"
        case .restart: "arrow.clockwise"
        case .reset: "gauge.with.dots.needle.0percent"
        }
    }

    /// Whether the action should be confirmed before it runs.
    var isDisruptive: Bool {
        switch self {
        case .start: false
        case .stop, .restart, .reset: true
        }
    }

    /// Whether the action makes sense for an instance in the given status.
    func isApplicable(to status: InstanceStatus) -> Bool {
        switch self {
        case .start: status != .running
        case .stop: status == .running
        case .restart, .reset: true
        }
    }
}
