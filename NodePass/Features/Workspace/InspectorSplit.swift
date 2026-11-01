//
//  InspectorSplit.swift
//  NodePass
//
//  The workspace's inspector pane: content on the leading side, a draggable divider and the
//  inspector along the trailing edge, laid out by hand so the window never has to grow for it.
//

#if os(macOS)
import AppKit
import SwiftUI

/// Content with an inspector pane along its trailing edge.
///
/// Not `.inspector`: on macOS 26 a system inspector inside a split view's detail column counts the
/// floating sidebar's width into its minimum twice, so once two sidebars plus the inspector exceed
/// the window (900pt at the defaults, more with any content minimum) AppKit loops its constraint
/// passes and aborts with "more Update Constraints in Window passes than there are views in the
/// window". This pane never asks for more than the window has: the layout takes the width it is
/// offered and the inspector gives way before the content does.
struct InspectorSplit<Content: View, Inspector: View>: View {
    var isPresented: Bool
    /// The pane's preferred width; the user drags the divider to change it.
    @Binding var width: Double
    @ViewBuilder var content: Content
    @ViewBuilder var inspector: Inspector

    var body: some View {
        TrailingPaneLayout(paneWidth: isPresented ? width : 0) {
            // Clipped like split view columns are: the filter chips scroll unclipped and would
            // otherwise draw over the pane.
            content
                .clipped()
            if isPresented {
                inspector
                    .clipped()
                PaneDivider(width: $width)
            }
        }
    }
}

private nonisolated enum PaneMetrics {
    static let minimumWidth: CGFloat = 320
    static let maximumWidth: CGFloat = 560
    /// The content keeps at least this much; the pane gives up the rest in a cramped window.
    static let minimumContentWidth: CGFloat = 200
    static let dividerWidth: CGFloat = 1
    /// The strip around the divider that takes the drag.
    static let dividerHitWidth: CGFloat = 9
}

/// Places `content`, then the pane and the divider over their seam. Subviews come in that order;
/// the pane and divider are absent while the pane is hidden.
private struct TrailingPaneLayout: Layout {
    /// 0 while the pane is hidden.
    var paneWidth: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        // Fully flexible: any minimum reported here is added to the window's, which is what must not
        // happen. The ideal is the content's plus the pane.
        let ideal = subviews.first?.sizeThatFits(.unspecified) ?? .zero
        return CGSize(width: proposal.width ?? ideal.width + paneWidth, height: proposal.height ?? ideal.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let content = subviews.first else { return }
        let hasPane = subviews.count == 3
        let paneWidth = hasPane ? min(paneWidth, max(0, bounds.width - PaneMetrics.minimumContentWidth)) : 0
        let contentWidth = bounds.width - paneWidth - (hasPane ? PaneMetrics.dividerWidth : 0)
        content.place(at: bounds.origin, anchor: .topLeading, proposal: ProposedViewSize(width: contentWidth, height: bounds.height))
        guard hasPane else { return }
        subviews[1].place(at: CGPoint(x: bounds.maxX - paneWidth, y: bounds.minY), anchor: .topLeading,
                          proposal: ProposedViewSize(width: paneWidth, height: bounds.height))
        subviews[2].place(at: CGPoint(x: bounds.minX + contentWidth - (PaneMetrics.dividerHitWidth - PaneMetrics.dividerWidth) / 2, y: bounds.minY),
                          anchor: .topLeading, proposal: ProposedViewSize(width: PaneMetrics.dividerHitWidth, height: bounds.height))
    }
}

/// A hairline with a wider invisible strip that resizes the pane when dragged.
private struct PaneDivider: View {
    @Binding var width: Double
    @State private var dragStartWidth: Double?

    var body: some View {
        ZStack {
            Color.clear
            Rectangle()
                .fill(.separator)
                .frame(width: PaneMetrics.dividerWidth)
        }
        .contentShape(Rectangle())
        .onHover { inside in
            if inside { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() }
        }
        .gesture(
            DragGesture(minimumDistance: 1)
                .onChanged { value in
                    let start = dragStartWidth ?? width
                    dragStartWidth = start
                    width = min(PaneMetrics.maximumWidth, max(PaneMetrics.minimumWidth, start - value.translation.width))
                }
                .onEnded { _ in dragStartWidth = nil }
        )
        .accessibilityHidden(true)
    }
}
#endif
