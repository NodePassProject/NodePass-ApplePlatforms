//
//  Panel.swift
//  NodePass
//
//  The building block of detail screens: a rounded card with a quiet header, laid out by
//  `MasonryLayout` into one or more columns. The panel-side counterpart of a form section, for
//  content that is read rather than edited. See docs/DESIGN.md.
//

import SwiftUI

struct Panel<Content: View, Accessory: View>: View {
    var title: String?
    var systemImage: String?
    /// Colors the header and lays a faint wash behind the panel.
    var tint: Color?
    @ViewBuilder var content: Content
    @ViewBuilder var accessory: Accessory

    init(_ title: String? = nil, systemImage: String? = nil, tint: Color? = nil,
         @ViewBuilder content: () -> Content, @ViewBuilder accessory: () -> Accessory) {
        self.title = title
        self.systemImage = systemImage
        self.tint = tint
        self.content = content()
        self.accessory = accessory()
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: DS.Radius.panel, style: .continuous)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            if title != nil || Accessory.self != EmptyView.self {
                header
            }
            content
        }
        .padding(DS.panelPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                shape.fill(.panelBackground)
                if let tint {
                    shape.fill(
                        LinearGradient(colors: [tint.opacity(0.12), tint.opacity(0.02), .clear],
                                       startPoint: .topLeading, endPoint: .bottom)
                    )
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.s) {
            if let title {
                Group {
                    if let systemImage {
                        Label(title, systemImage: systemImage)
                    } else {
                        Text(title)
                    }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint.map(AnyShapeStyle.init) ?? AnyShapeStyle(.secondary))
                .lineLimit(1)
                .accessibilityAddTraits(.isHeader)
            }
            Spacer(minLength: 0)
            accessory
                .font(.subheadline)
                .buttonStyle(.borderless)
                .controlSize(.small)
        }
    }
}

extension Panel where Accessory == EmptyView {
    init(_ title: String? = nil, systemImage: String? = nil, tint: Color? = nil, @ViewBuilder content: () -> Content) {
        self.init(title, systemImage: systemImage, tint: tint, content: content) { EmptyView() }
    }
}

/// Rows separated by hairlines, the way a form section separates them, for use inside a panel.
struct PanelRows<Content: View>: View {
    var rowSpacing: CGFloat = 9
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Group(subviews: content) { subviews in
                ForEach(Array(subviews.enumerated()), id: \.element.id) { index, subview in
                    subview
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, rowSpacing)
                    if index < subviews.count - 1 {
                        Divider()
                    }
                }
            }
        }
        .padding(.vertical, -rowSpacing)
    }
}

/// A key on the leading edge, a value on the trailing edge: the panel row for one fact.
struct PropertyRow<Value: View>: View {
    var key: String
    var value: Value

    init(_ key: String, @ViewBuilder value: () -> Value) {
        self.key = key
        self.value = value()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.m) {
            Text(key)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Spacer(minLength: DS.Spacing.s)
            value
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
    }
}

extension PropertyRow where Value == Text {
    /// A monospaced, copyable text value. Empty values show the placeholder dimmed.
    init(_ key: String, value: String, placeholder: String = "—") {
        self.key = key
        self.value = Text(value.isEmpty ? placeholder : value)
            .font(.code(.callout))
            .foregroundStyle(value.isEmpty ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.primary))
    }
}

/// `PropertyRow` with a copy item in its context menu.
struct CopyablePropertyRow: View {
    var key: String
    var value: String
    var placeholder: String = "—"

    var body: some View {
        PropertyRow(key, value: value, placeholder: placeholder)
            .textSelection(.enabled)
            .contextMenu {
                if !value.isEmpty {
                    Button("Copy \(key)", systemImage: "document.on.document") { Clipboard.copy(value) }
                }
            }
    }
}

/// A screen made of a hero header and panels: the hero sits on a wash in the subject's tint that
/// fades into the canvas, the panels follow in a masonry.
struct PanelScreen<Hero: View, Content: View>: View {
    var tint: Color
    @ViewBuilder var hero: Hero
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.l) {
                hero
                    .padding(.top, DS.Spacing.s)
                MasonryLayout(spacing: DS.Spacing.m) {
                    content
                }
            }
            .padding(.horizontal, DS.Spacing.l)
            .padding(.bottom, DS.Spacing.xl)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background {
            ZStack(alignment: .top) {
                Color.canvasBackground
                HeroWash(tint: tint)
                    .frame(height: 300)
            }
            .ignoresSafeArea()
        }
    }
}
