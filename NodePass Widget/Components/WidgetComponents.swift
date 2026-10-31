//
//  WidgetComponents.swift
//  NodePass Widget
//
//  Building blocks shared by the widget layouts.
//
//  Widgets are not always drawn in full color: a Mac desktop in the background renders them
//  "vibrant" (monochrome), and tinted Home Screens render them "accented". Status therefore reads
//  from symbol shape first and color second.
//

import SwiftUI
import WidgetKit
import AppIntents

extension WidgetRenderingMode {
    /// `color` in full color; the primary style otherwise, where hues are lost anyway.
    func tint(_ color: Color) -> Color {
        self == .fullColor ? color : .primary
    }
}

/// Status of one instance as a symbol whose shape alone tells the state apart.
struct StatusGlyph: View {
    @Environment(\.widgetRenderingMode) private var renderingMode

    var status: InstanceStatus

    var body: some View {
        Image(systemName: symbolName)
            .foregroundStyle(renderingMode.tint(status.tint))
            .accessibilityLabel(status.title)
    }

    private var symbolName: String {
        switch status {
        case .running: "circle.fill"
        case .stopped: "circle"
        case .error: "exclamationmark.triangle.fill"
        case .other: "questionmark.circle"
        }
    }
}

/// Overall state of a master: reachable and healthy, reporting errors, or unreachable.
struct MasterHealthGlyph: View {
    @Environment(\.widgetRenderingMode) private var renderingMode

    var report: MasterReport

    var body: some View {
        Image(systemName: symbolName)
            .foregroundStyle(renderingMode.tint(color))
            .widgetAccentable()
            .accessibilityLabel(accessibilityText)
    }

    private var symbolName: String {
        if !report.isReachable { return "bolt.horizontal.circle" }
        return report.errors > 0 ? "exclamationmark.triangle.fill" : "checkmark.circle.fill"
    }

    private var color: Color {
        if !report.isReachable { return .secondary }
        return report.errors > 0 ? .red : .green
    }

    private var accessibilityText: String {
        if !report.isReachable { return "Unreachable" }
        return report.errors > 0 ? "\(report.errors) instances report errors" : "Healthy"
    }
}

/// Host metrics as ring gauges, one view per metric so callers can lay them out in a row or a grid.
struct HostRings: View {
    enum Metric: CaseIterable {
        case cpu, memory, swap, network
    }

    @Environment(\.widgetRenderingMode) private var renderingMode

    var info: MasterInfo
    var size: CGFloat
    var metrics: [Metric] = Metric.allCases

    var body: some View {
        ForEach(metrics, id: \.self) { metric in
            gauge(metric)
                .widgetAccentable()
        }
    }

    @ViewBuilder
    private func gauge(_ metric: Metric) -> some View {
        switch metric {
        case .cpu:
            ring("CPU", value: info.cpuRatio, label: info.cpuUsage < 0 ? "—" : "\(info.cpuUsage)%", tint: .blue)
        case .memory:
            ring("Memory", value: info.memoryRatio, label: Format.percent(info.memoryRatio), tint: .purple)
        case .swap:
            ring("Swap", value: info.swapRatio, label: info.swapTotal == 0 ? "—" : Format.percent(info.swapRatio), tint: .teal)
        case .network:
            let total = Double(info.networkReceived + info.networkTransmitted)
            Gauge(value: total == 0 ? 0 : Double(info.networkReceived) / total) {
                Text("Network")
            } currentValueLabel: {
                EmptyView()
            }
            .gaugeStyle(SplitRingGaugeStyle(
                primaryText: "↓ \(Format.bytes(info.networkReceived, decimals: 0))",
                secondaryText: "↑ \(Format.bytes(info.networkTransmitted, decimals: 0))",
                primaryTint: renderingMode.tint(.blue),
                secondaryTint: renderingMode == .fullColor ? .orange : .secondary,
                size: size))
        }
    }

    private func ring(_ title: String, value: Double, label: String, tint: Color) -> some View {
        Gauge(value: value) {
            Text(title)
        } currentValueLabel: {
            Text(label)
        }
        .gaugeStyle(RingGaugeStyle(tint: renderingMode.tint(tint), size: size))
    }
}

/// Running, stopped and error counts.
struct InstanceCounts: View {
    var report: MasterReport

    var body: some View {
        HStack(spacing: 8) {
            Label {
                Text("\(report.running)")
            } icon: {
                StatusGlyph(status: .running)
            }
            Label {
                Text("\(report.stopped)")
            } icon: {
                StatusGlyph(status: .stopped)
            }
            if report.errors > 0 {
                Label {
                    Text("\(report.errors)")
                } icon: {
                    StatusGlyph(status: .error)
                }
            }
        }
        .labelStyle(.titleAndIcon)
        .font(.caption2.monospacedDigit())
        .fixedSize()
    }
}

/// One instance; opens it in the app.
struct InstanceRow: View {
    enum Detail { case compact, full }

    var instance: Instance
    var masterID: String
    var detail: Detail = .compact

    var body: some View {
        Link(destination: DeepLink.master(masterID, instance: instance.id)) {
            switch detail {
            case .compact:
                row(showsDetails: false)
            case .full:
                // Type and connections only when the widget is wide enough to keep the name.
                ViewThatFits(in: .horizontal) {
                    row(showsDetails: true)
                    row(showsDetails: false)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func row(showsDetails: Bool) -> some View {
        HStack(spacing: 6) {
            StatusGlyph(status: instance.status)
                .font(.system(size: 8))
                .frame(width: 10)
            Text(instance.displayName)
                .font(.caption.weight(.medium))
            if showsDetails {
                Text(instance.role.title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 6)
            if showsDetails, instance.totalConnections > 0 {
                Label("\(instance.totalConnections)", systemImage: "point.3.connected.trianglepath.dotted")
                    .labelStyle(.titleAndIcon)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Text("↓\(Format.bytes(instance.totalReceived, decimals: 0)) ↑\(Format.bytes(instance.totalTransmitted, decimals: 0))")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .lineLimit(1)
    }
}

/// As many rows as the widget has room for. Widget sizes differ a lot between a Mac desktop, an
/// iPad and an iPhone, so the layout tries `limits` from largest to smallest and keeps the first
/// that fits.
struct FittingRows<Content: View>: View {
    var limits: [Int]
    @ViewBuilder var content: (Int) -> Content

    var body: some View {
        ViewThatFits(in: .vertical) {
            ForEach(limits, id: \.self) { limit in
                content(limit)
            }
        }
    }
}

/// When the data was fetched; tapping reloads it.
struct RefreshButton: View {
    var date: Date

    var body: some View {
        Button(intent: RefreshWidgetIntent()) {
            HStack(spacing: 3) {
                Text(date, style: .time)
                Image(systemName: "arrow.clockwise")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Refresh")
    }
}

/// A centered message with a retry button, for missing configuration or unreachable masters.
struct WidgetMessage: View {
    var title: String?
    var message: String
    var symbolName = "server.rack"

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: symbolName)
                .font(.title2)
                .foregroundStyle(.secondary)
            if let title {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
            }
            Text(message)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
            Button(intent: RefreshWidgetIntent()) {
                Label("Retry", systemImage: "arrow.clockwise")
                    .font(.caption)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
