//
//  PlatformAdaptations.swift
//  NodePass
//
//  Thin wrappers over modifiers that exist on only one platform, so shared views read the same
//  everywhere and the platform differences live in one place.
//

import SwiftUI

/// The kind of text a field expects.
enum TextInputKind {
    case plain
    case url
    case number

    #if os(iOS)
    fileprivate var keyboardType: UIKeyboardType {
        switch self {
        case .plain: .default
        case .url: .URL
        case .number: .numberPad
        }
    }
    #endif
}

extension View {
    /// Machine-readable input: no auto-correction or capitalization, and a matching keyboard on iOS.
    func codeInput(_ kind: TextInputKind = .plain) -> some View {
        #if os(iOS)
        autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .keyboardType(kind.keyboardType)
        #else
        autocorrectionDisabled()
        #endif
    }

    /// Inline navigation bar title on iOS. macOS shows titles in the window or not at all.
    func inlineNavigationTitle() -> some View {
        #if os(iOS)
        navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }

    /// A comfortable default size for a sheet on macOS, where sheets otherwise shrink to their
    /// content. iOS sizes sheets itself.
    func sheetFrame(width: CGFloat, height: CGFloat) -> some View {
        #if os(macOS)
        frame(minWidth: width, idealWidth: width, minHeight: height, idealHeight: height)
        #else
        self
        #endif
    }
}

extension ShapeStyle where Self == Color {
    /// Background of small cards that sit on grouped content.
    static var tileBackground: Color {
        #if os(macOS)
        Color(nsColor: .quaternarySystemFill)
        #else
        Color(uiColor: .secondarySystemGroupedBackground)
        #endif
    }
}
