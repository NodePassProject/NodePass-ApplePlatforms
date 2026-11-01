//
//  MasonryLayout.swift
//  NodePass
//
//  Places panels into the shortest of n columns, n following the available width: one on an
//  iPhone, two or three on an iPad or in a wide window. A panel can ask to span every column.
//

import SwiftUI

struct MasonryLayout: Layout {
    /// A column is never narrower than this; the count follows from the width.
    var minColumnWidth: CGFloat = 330
    var maxColumns = 3
    var spacing: CGFloat = 12

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        // No width, or an unbounded one (an inspector measuring its content), asks for the ideal:
        // one column. Answering with more than that makes the hosting view re-measure forever.
        let width = proposal.width.map { $0.isFinite ? $0 : minColumnWidth } ?? minColumnWidth
        let frames = frames(forWidth: width, subviews: subviews)
        return CGSize(width: width, height: frames.map(\.maxY).max() ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let frames = frames(forWidth: bounds.width, subviews: subviews)
        for (subview, frame) in zip(subviews, frames) {
            subview.place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                          anchor: .topLeading,
                          proposal: ProposedViewSize(width: frame.width, height: frame.height))
        }
    }

    private func frames(forWidth width: CGFloat, subviews: Subviews) -> [CGRect] {
        let width = width.isFinite ? width : minColumnWidth
        let columns = max(1, min(maxColumns, Int((width + spacing) / (minColumnWidth + spacing))))
        let columnWidth = (width - spacing * CGFloat(columns - 1)) / CGFloat(columns)
        // Bottom edge of the last item in each column; 0 while the column is empty.
        var bottoms = Array(repeating: CGFloat(0), count: columns)
        var frames: [CGRect] = []
        frames.reserveCapacity(subviews.count)

        for subview in subviews {
            if columns == 1 || subview[SpansAllColumns.self] {
                let top = bottoms.max() ?? 0
                let y = top == 0 ? 0 : top + spacing
                let height = subview.sizeThatFits(ProposedViewSize(width: width, height: nil)).height
                frames.append(CGRect(x: 0, y: y, width: width, height: height))
                bottoms = Array(repeating: y + height, count: columns)
            } else {
                let column = bottoms.indices.min { bottoms[$0] < bottoms[$1] } ?? 0
                let y = bottoms[column] == 0 ? 0 : bottoms[column] + spacing
                let height = subview.sizeThatFits(ProposedViewSize(width: columnWidth, height: nil)).height
                frames.append(CGRect(x: CGFloat(column) * (columnWidth + spacing), y: y, width: columnWidth, height: height))
                bottoms[column] = y + height
            }
        }
        return frames
    }
}

private nonisolated struct SpansAllColumns: LayoutValueKey {
    static let defaultValue = false
}

extension View {
    /// In a `MasonryLayout`, take the full width instead of one column.
    func spansAllColumns(_ spans: Bool = true) -> some View {
        layoutValue(key: SpansAllColumns.self, value: spans)
    }
}
