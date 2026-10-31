//
//  MasterSession+Health.swift
//  NodePass Watch App
//
//  A master's state boiled down to one word and one color, for rows, headers and the gradient
//  behind a master's screens.
//

import SwiftUI

extension MasterSession {
    enum Health: Hashable {
        case disabled
        case connecting
        case offline
        case errors(Int)
        case online

        var title: String {
            switch self {
            case .disabled: "Disabled"
            case .connecting: "Connecting"
            case .offline: "Offline"
            case .errors(let count): count == 1 ? "1 Error" : "\(count) Errors"
            case .online: "Online"
            }
        }

        var symbolName: String {
            switch self {
            case .disabled: "pause.circle"
            case .connecting: "antenna.radiowaves.left.and.right"
            case .offline: "bolt.horizontal.circle"
            case .errors: "exclamationmark.triangle.fill"
            case .online: "checkmark.circle.fill"
            }
        }

        var tint: Color {
            switch self {
            case .disabled: .gray
            case .connecting: .secondary
            case .offline: .red
            case .errors: .orange
            case .online: .green
            }
        }
    }

    var health: Health {
        guard snapshot.isEnabled else { return .disabled }
        switch connection {
        case .offline:
            return .offline
        case .idle, .connecting, .live, .polling:
            // Polling starts before the first instance list arrives; until then nothing is known.
            return hasLoadedInstances ? loadedHealth : .connecting
        }
    }

    private var loadedHealth: Health {
        errorCount > 0 ? .errors(errorCount) : .online
    }

    /// What the connection is doing, in the words the iPhone app uses.
    var connectionDetail: String {
        switch connection {
        case .live:
            if let date = lastEventDate { return "Live · \(Format.relative(date))" }
            return "Receiving live events"
        case .polling:
            return "Polling every \(Int(instancePollInterval)) s"
        case .connecting:
            return "Opening event stream…"
        case .offline(let reason):
            return reason
        case .idle:
            return snapshot.isEnabled ? "Paused" : "Disabled on iPhone"
        }
    }
}

/// Overall state of a master as a symbol whose shape tells the states apart before color does.
struct HealthGlyph: View {
    var health: MasterSession.Health

    var body: some View {
        Image(systemName: health.symbolName)
            .foregroundStyle(health.tint)
            .symbolEffect(.pulse, options: .repeating, isActive: health == .connecting)
            .accessibilityLabel(health.title)
    }
}
