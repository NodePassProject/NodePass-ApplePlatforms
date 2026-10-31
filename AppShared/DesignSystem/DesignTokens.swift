//
//  DesignTokens.swift
//  NodePass
//
//  Spacing, radii, type and motion shared by every screen. See docs/DESIGN.md.
//

import SwiftUI

enum DS {
    enum Spacing {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 20
    }

    enum Radius {
        /// Panels and cards, matching the grouped sections of the platform.
        static var panel: CGFloat {
            #if os(macOS)
            14
            #else
            22
            #endif
        }

        /// Tiles and controls that sit inside a panel.
        static var tile: CGFloat {
            #if os(macOS)
            10
            #else
            14
            #endif
        }
    }

    /// Inner padding of a panel.
    static var panelPadding: CGFloat {
        #if os(macOS)
        14
        #else
        16
        #endif
    }
}

extension Font {
    /// Numbers that change: rounded design with monospaced digits.
    static func numeral(_ style: Font.TextStyle, weight: Font.Weight = .semibold) -> Font {
        .system(style, design: .rounded).weight(weight).monospacedDigit()
    }

    /// Machine text: URLs, identifiers, keys, log lines.
    static func code(_ style: Font.TextStyle) -> Font {
        .system(style, design: .monospaced)
    }
}

extension Animation {
    /// Selection, filters and layout changes.
    static let signal = Animation.snappy(duration: 0.3)
    /// Values arriving from a master.
    static let liveValue = Animation.smooth(duration: 0.45)
}

extension ShapeStyle where Self == Color {
    /// The screen behind panels. The Mac keeps its window or inspector material.
    static var canvasBackground: Color {
        #if os(iOS)
        Color(uiColor: .systemGroupedBackground)
        #else
        Color.clear
        #endif
    }

    /// Panels and cards.
    static var panelBackground: Color {
        #if os(macOS)
        Color(nsColor: .quaternarySystemFill)
        #elseif os(watchOS)
        Color.white.opacity(0.12)
        #else
        Color(uiColor: .secondarySystemGroupedBackground)
        #endif
    }

    /// Tiles and controls inside a panel.
    static var tileBackground: Color {
        #if os(macOS)
        Color(nsColor: .quinarySystemFill)
        #elseif os(watchOS)
        Color.white.opacity(0.08)
        #else
        Color(uiColor: .tertiarySystemGroupedBackground)
        #endif
    }
}
