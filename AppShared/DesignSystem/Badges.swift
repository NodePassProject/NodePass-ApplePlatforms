//
//  Badges.swift
//  NodePass
//
//  Small status and role indicators used across lists, cards and headers.
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

/// Filled status dot. With `ripples`, a running instance sends out a soft ring every couple of
/// seconds; that is reserved for the one subject on screen, lists stay still.
struct StatusDot: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var status: InstanceStatus
    var size: CGFloat = 9
    var ripples = false

    private var isAnimating: Bool { ripples && status == .running && !reduceMotion }

    var body: some View {
        ZStack {
            if ripples {
                TimelineView(.animation(minimumInterval: 1 / 30, paused: !isAnimating)) { context in
                    let period = 2.0
                    let progress = isAnimating ? context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period) / period : 0
                    Circle()
                        .stroke(status.tint.opacity(isAnimating ? (1 - progress) * 0.7 : 0), lineWidth: 1.5)
                        .scaleEffect(1 + progress * 1.8)
                }
            }
            Circle()
                .fill(status.tint)
        }
        .frame(width: size, height: size)
        .accessibilityLabel(status.title)
    }
}

/// Status of an instance as a symbol whose shape alone tells the state apart.
struct StatusGlyph: View {
    var status: InstanceStatus

    var body: some View {
        Image(systemName: status.symbolName)
            .foregroundStyle(status.tint)
            .accessibilityLabel(status.title)
    }
}

extension View {
    /// The signal bar: a thin capsule along the leading edge in the status or role tint. Rows and
    /// cards carry their state here, where the eye lands first.
    func signalBar(_ tint: Color, width: CGFloat = 3, spacing: CGFloat = 10) -> some View {
        padding(.leading, width + spacing)
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(tint)
                    .frame(width: width)
                    .padding(.vertical, 1)
                    .accessibilityHidden(true)
            }
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
        .animation(.signal, value: prominent)
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var state: ConnectionState
    var showsTitle = true

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: state.symbolName)
                .foregroundStyle(state.tint)
                .symbolEffect(.pulse, options: .repeating, isActive: state == .connecting && !reduceMotion)
                .symbolEffect(.breathe, options: .repeating, isActive: state == .live && !reduceMotion)
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
