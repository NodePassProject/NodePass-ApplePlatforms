//
//  Metrics.swift
//  NodePass
//
//  Tiles and sparklines for live numbers.
//

import SwiftUI

extension ShapeStyle where Self == Color {
    /// Background of small cards that sit on grouped content.
    static var tileBackground: Color {
        #if os(macOS)
        Color(nsColor: .quaternarySystemFill)
        #elseif os(watchOS)
        Color.white.opacity(0.12)
        #else
        Color(uiColor: .secondarySystemGroupedBackground)
        #endif
    }
}

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
            Text(value)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if let detail {
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.tileBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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
    }
}
