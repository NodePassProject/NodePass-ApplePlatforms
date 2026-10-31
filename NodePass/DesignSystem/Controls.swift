//
//  Controls.swift
//  NodePass
//
//  Shared small controls: monospaced value rows, copy buttons, flow layout, inline messages.
//

import SwiftUI

/// Monospaced text that can be copied from its context menu.
struct MonoText: View {
    var text: String
    var lineLimit: Int? = nil
    var size: Font.TextStyle = .callout

    var body: some View {
        Text(text)
            .font(.system(size, design: .monospaced))
            .lineLimit(lineLimit)
            .textSelection(.enabled)
            .contextMenu {
                Button("Copy", systemImage: "document.on.document") { Clipboard.copy(text) }
            }
    }
}

/// `LabeledContent` with a monospaced, copyable value.
struct KeyValueRow: View {
    var key: String
    var value: String
    var placeholder: String = "—"
    var copyable = true

    var body: some View {
        LabeledContent(key) {
            Text(value.isEmpty ? placeholder : value)
                .font(.callout.monospaced())
                .foregroundStyle(value.isEmpty ? .tertiary : .primary)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
        .contextMenu {
            if copyable, !value.isEmpty {
                Button("Copy \(key)", systemImage: "document.on.document") { Clipboard.copy(value) }
            }
        }
    }
}

struct CopyButton: View {
    var text: String
    var label: String = "Copy"

    @State private var copied = false

    var body: some View {
        Button {
            Clipboard.copy(text)
            Haptics.selection()
            withAnimation { copied = true }
            Task {
                try? await Task.sleep(for: .seconds(1.2))
                withAnimation { copied = false }
            }
        } label: {
            Label(copied ? "Copied" : label, systemImage: copied ? "checkmark" : "document.on.document")
        }
        .disabled(text.isEmpty)
    }
}

/// Wraps subviews onto multiple lines.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, maxX: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            maxX = max(maxX, x - spacing)
        }
        return CGSize(width: width == .infinity ? maxX : width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

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

/// Text field tuned for machine-readable input (no autocorrect or capitalization).
struct CodeField: View {
    var title: String
    @Binding var text: String
    var prompt: String? = nil
    var input: TextInputKind = .plain
    var axis: Axis = .horizontal

    var body: some View {
        TextField(text: $text, prompt: prompt.map { Text($0) }, axis: axis) {
            // macOS forms show the label beside the field; only the value is code.
            Text(title)
                .font(.body)
        }
        .font(.body.monospaced())
        .codeInput(input)
    }
}

/// An element with an ID that stays unique across sibling `ForEach`es in one list section, where
/// plain offsets from two sequences would collide and rows would render in each other's place.
struct ScopedRow<Element>: Identifiable {
    let id: String
    let index: Int
    let element: Element
}

extension Sequence {
    func scopedRows(_ scope: String) -> [ScopedRow<Element>] {
        enumerated().map { ScopedRow(id: "\(scope)-\($0.offset)", index: $0.offset, element: $0.element) }
    }
}
