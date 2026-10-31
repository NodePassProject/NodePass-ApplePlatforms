//
//  Badges.swift
//  NodePass
//
//  Small status and role indicators used across lists and headers.
//

import SwiftUI

extension ConnectionState {
    var tint: Color {
        switch self {
        case .idle: .gray
        case .connecting: .yellow
        case .live: .green
        case .polling: .blue
        case .offline: .red
        }
    }

    var symbolName: String {
        switch self {
        case .idle: "pause.circle"
        case .connecting: "antenna.radiowaves.left.and.right"
        case .live: "bolt.horizontal.circle.fill"
        case .polling: "clock.arrow.2.circlepath"
        case .offline: "wifi.exclamationmark"
        }
    }
}

/// Filled status dot with optional pulsing when running.
struct StatusDot: View {
    var status: InstanceStatus
    var size: CGFloat = 9

    var body: some View {
        Circle()
            .fill(status.tint)
            .frame(width: size, height: size)
            .accessibilityLabel(status.title)
    }
}

/// Capsule label with a tinted background.
struct Pill: View {
    @Environment(\.backgroundProminence) private var backgroundProminence

    var text: String
    var tint: Color
    var systemImage: String? = nil
    var prominent = false

    /// On a selected table or list row, tinted text would vanish into the highlight.
    private var isOnSelection: Bool { backgroundProminence == .increased }

    private var foreground: Color {
        prominent || isOnSelection ? .white : tint
    }

    private var background: AnyShapeStyle {
        if isOnSelection { return AnyShapeStyle(.white.opacity(0.22)) }
        return prominent ? AnyShapeStyle(tint) : AnyShapeStyle(tint.opacity(0.14))
    }

    var body: some View {
        HStack(spacing: 3) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 9, weight: .bold))
            }
            Text(text)
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
        }
        .fixedSize()
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .foregroundStyle(foreground)
        .background(background, in: Capsule())
    }
}

struct StatusPill: View {
    var status: InstanceStatus
    var prominent = false

    var body: some View {
        Pill(text: status.title, tint: status.tint, prominent: prominent)
    }
}

struct RolePill: View {
    var role: InstanceRole

    var body: some View {
        Pill(text: role.title, tint: role.tint, systemImage: role.symbolName)
    }
}

struct ConnectionIndicator: View {
    var state: ConnectionState
    var showsTitle = true

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: state.symbolName)
                .foregroundStyle(state.tint)
                .symbolEffect(.pulse, options: .repeating, isActive: state == .connecting)
            if showsTitle {
                Text(state.title)
                    .foregroundStyle(.secondary)
            }
        }
        .font(.caption)
        .accessibilityLabel("Connection: \(state.title)")
    }
}

/// A tag chip `key: value` with monospaced styling.
struct TagChip: View {
    var key: String
    var value: String

    var body: some View {
        HStack(spacing: 0) {
            Text(key)
                .fontWeight(.semibold)
            if !value.isEmpty {
                Text(": ")
                Text(value)
                    .foregroundStyle(.secondary)
            }
        }
        .font(.caption2.monospaced())
        .lineLimit(1)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 5))
    }
}
