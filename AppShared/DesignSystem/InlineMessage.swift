//
//  InlineMessage.swift
//  NodePass
//
//  Inline banner for forms, detail screens and Siri snippets.
//

import SwiftUI

/// Inline error banner for forms and detail screens.
struct InlineMessage: View {
    enum Style { case error, warning, info, success }

    var text: String
    var style: Style = .error

    private var tint: Color {
        switch style {
        case .error: .red
        case .warning: .orange
        case .info: .blue
        case .success: .green
        }
    }

    private var symbol: String {
        switch style {
        case .error: "xmark.octagon.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .info: "info.circle.fill"
        case .success: "checkmark.circle.fill"
        }
    }

    var body: some View {
        Label {
            Text(text)
                .font(.footnote)
        } icon: {
            Image(systemName: symbol)
                .foregroundStyle(tint)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

extension ValidationIssue.Severity {
    var messageStyle: InlineMessage.Style {
        switch self {
        case .error: .error
        case .warning: .warning
        case .info: .info
        }
    }
}
