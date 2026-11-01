//
//  Metrics.swift
//  NodePass
//
//  Tiles and sparklines for live numbers.
//

import SwiftUI

/// A labeled number. The value is set in the rounded numeral face and animates between values.
struct MetricTile: View {
    var title: String
    var value: String
    var detail: String? = nil
    var systemImage: String? = nil
    var tint: Color = .accentColor

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .foregroundStyle(tint)
                }
                Text(title)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            Text(value)
                .font(.numeral(.title3))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .contentTransition(.numericText())
                .animation(.liveValue, value: value)
            if let detail {
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.m)
        .background(.tileBackground, in: RoundedRectangle(cornerRadius: DS.Radius.tile, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// Lays metric tiles into as many equal columns as the width allows.
struct MetricGrid<Content: View>: View {
    var minimumTileWidth: CGFloat = 92
    @ViewBuilder var content: Content

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: minimumTileWidth, maximum: 260), spacing: DS.Spacing.s)], spacing: DS.Spacing.s) {
            content
        }
    }
}

/// Lightweight line sparkline. Values are normalized against `maximum` (or the series peak).
struct Sparkline: View {
    var values: [Double]
    var tint: Color = .accentColor
    var maximum: Double? = nil
    var fill = true

    var body: some View {
        GeometryReader { proxy in
            let peak = max(maximum ?? values.max() ?? 1, 0.000_001)
            let count = max(values.count, 2)
            let stepX = proxy.size.width / CGFloat(count - 1)
            let points = values.enumerated().map { index, value in
                CGPoint(x: CGFloat(index) * stepX,
                        y: proxy.size.height - CGFloat(value / peak) * proxy.size.height)
            }
            ZStack {
                if fill, points.count > 1 {
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: proxy.size.height))
                        for point in points { path.addLine(to: point) }
                        path.addLine(to: CGPoint(x: points.last?.x ?? 0, y: proxy.size.height))
                        path.closeSubpath()
                    }
                    .fill(LinearGradient(colors: [tint.opacity(0.35), tint.opacity(0.02)], startPoint: .top, endPoint: .bottom))
                }
                Path { path in
                    guard let first = points.first else { return }
                    path.move(to: first)
                    for point in points.dropFirst() { path.addLine(to: point) }
                }
                .stroke(tint, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
            }
        }
        .accessibilityHidden(true)
    }
}

/// Two overlapping sparklines (received / transmitted) sharing one scale.
struct TrafficSparkline: View {
    var samples: [RateSample]
    var height: CGFloat = 44

    var body: some View {
        let peak = max(samples.map { max($0.received, $0.transmitted) }.max() ?? 1, 1)
        ZStack {
            Sparkline(values: samples.map(\.received), tint: .blue, maximum: peak)
            Sparkline(values: samples.map(\.transmitted), tint: .orange, maximum: peak, fill: false)
        }
        .frame(height: height)
    }
}

struct RateLegend: View {
    var received: Double
    var transmitted: Double

    var body: some View {
        HStack(spacing: 12) {
            Label(Format.bitRate(bytesPerSecond: received), systemImage: "arrow.down")
                .foregroundStyle(.blue)
            Label(Format.bitRate(bytesPerSecond: transmitted), systemImage: "arrow.up")
                .foregroundStyle(.orange)
        }
        .font(.caption.monospacedDigit())
        .labelStyle(.titleAndIcon)
        .lineLimit(1)
        // An HStack hands each flexible child an equal share of its width before it knows what
        // the child needs, so next to another label in a narrow column the unit wrapped onto a
        // second line ("4.8\nMbps"). A rate is always one line; the neighbours give way instead.
        .fixedSize(horizontal: true, vertical: false)
        .contentTransition(.numericText())
        .animation(.liveValue, value: received + transmitted)
    }
}
