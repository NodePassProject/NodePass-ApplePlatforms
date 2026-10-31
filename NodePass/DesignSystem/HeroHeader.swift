//
//  HeroHeader.swift
//  NodePass
//
//  The head of a detail screen: who this is, in what state, and what you can do about it. The
//  wash behind it is a mesh gradient in the subject's tint that fades into the canvas.
//

import SwiftUI

/// Identity block of a detail screen. Callers compose the rows; this sets the type and rhythm.
struct HeroHeader<Badges: View, Meta: View, Actions: View>: View {
    var title: String
    @ViewBuilder var badges: Badges
    @ViewBuilder var meta: Meta
    @ViewBuilder var actions: Actions

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            HStack(spacing: DS.Spacing.s) {
                badges
            }
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(title)
                    .font(.title.weight(.bold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .accessibilityAddTraits(.isHeader)
                meta
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            actions
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The tinted mesh behind a hero header.
struct HeroWash: View {
    @Environment(\.colorScheme) private var colorScheme

    var tint: Color

    private var strength: Double {
        #if os(macOS)
        colorScheme == .dark ? 0.34 : 0.26
        #else
        colorScheme == .dark ? 0.46 : 0.38
        #endif
    }

    var body: some View {
        MeshGradient(
            width: 3, height: 3,
            points: [
                [0.0, 0.0], [0.5, 0.0], [1.0, 0.0],
                [0.0, 0.42], [0.58, 0.5], [1.0, 0.38],
                [0.0, 1.0], [0.5, 1.0], [1.0, 1.0],
            ],
            colors: [
                tint.opacity(strength), tint.opacity(strength * 0.75), tint.opacity(strength * 0.4),
                tint.opacity(strength * 0.45), tint.opacity(strength * 0.22), tint.opacity(strength * 0.08),
                .clear, .clear, .clear,
            ]
        )
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// A big state line for a hero header: shaped glyph, state word and a tint, with the ripple of a
/// running instance.
struct StateBadge: View {
    var title: String
    var tint: Color
    var systemImage: String

    var body: some View {
        Label {
            Text(title)
                .font(.subheadline.weight(.semibold))
        } icon: {
            Image(systemName: systemImage)
                .symbolRenderingMode(.hierarchical)
        }
        .foregroundStyle(tint)
        .labelStyle(.titleAndIcon)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(tint.opacity(0.14), in: Capsule())
        .contentTransition(.symbolEffect(.replace))
        .animation(.signal, value: title)
    }
}
