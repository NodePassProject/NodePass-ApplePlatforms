//
//  GaugeStyles.swift
//  NodePass
//
//  Compact ring gauges shared by the app and the widget.
//

import SwiftUI

struct RingGaugeStyle: GaugeStyle {
    var tint: Color
    var size: CGFloat
    var lineWidth: CGFloat { max(3, size / 9) }

    func makeBody(configuration: Configuration) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(.quaternary, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                Circle()
                    .trim(from: 0, to: CGFloat(configuration.value))
                    .rotation(.degrees(-90))
                    .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .animation(.smooth, value: configuration.value)
                configuration.currentValueLabel
                    .font(.system(size: size * 0.26, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
                    .padding(lineWidth + 2)
            }
            .frame(width: size, height: size)
            configuration.label
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

/// Two-tone ring showing a split (e.g. transmitted vs received) with two value lines.
struct SplitRingGaugeStyle: GaugeStyle {
    var primaryText: String
    var secondaryText: String
    var primaryTint: Color
    var secondaryTint: Color
    var size: CGFloat
    var lineWidth: CGFloat { max(3, size / 9) }

    func makeBody(configuration: Configuration) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(secondaryTint.opacity(0.85), style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
                Circle()
                    .trim(from: 0, to: CGFloat(configuration.value))
                    .rotation(.degrees(-90))
                    .stroke(primaryTint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
                    .animation(.smooth, value: configuration.value)
                VStack(spacing: 1) {
                    Text(primaryText)
                    Text(secondaryText)
                }
                .font(.system(size: max(8, size * 0.17), weight: .medium, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.5)
                .padding(lineWidth + 2)
            }
            .frame(width: size, height: size)
            configuration.label
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
