//
//  FleetView.swift
//  NodePass Widget
//

import WidgetKit
import SwiftUI

struct FleetWidgetView: View {
    @Environment(\.widgetFamily) private var family

    var entry: FleetEntry

    var body: some View {
        content
            .containerBackground(.background, for: .widget)
    }

    @ViewBuilder
    private var content: some View {
        if entry.reports.isEmpty {
            WidgetMessage(message: "Add or enable a master in NodePass.")
        } else {
            FleetLayout(reports: entry.reports, family: family, date: entry.date)
        }
    }
}

/// The layouts of the Masters widget, one per widget family.
struct FleetLayout: View {
    @Environment(\.widgetRenderingMode) private var renderingMode

    var reports: [MasterReport]
    var family: WidgetFamily
    var date: Date

    private var reachable: Int { reports.filter(\.isReachable).count }
    private var running: Int { reports.reduce(0) { $0 + $1.running } }
    private var errors: Int { reports.reduce(0) { $0 + $1.errors } }
    private var isHealthy: Bool { reachable == reports.count && errors == 0 }

    var body: some View {
        switch family {
        case .systemSmall: small
        case .systemLarge: rows(limits: [9, 7, 5, 3], style: .detailed)
        case .systemExtraLarge: table
        default: rows(limits: [4, 3, 2, 1], style: .line)
        }
    }

    // MARK: Families

    private var small: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Masters")
                    .font(.caption.weight(.semibold))
                Spacer()
                Image(systemName: isHealthy ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(renderingMode.tint(isHealthy ? .green : .orange))
                    .widgetAccentable()
            }
            Spacer(minLength: 0)
            Text("\(reachable)/\(reports.count)")
                .font(.system(size: 34, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .widgetAccentable()
            Text("reachable")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            totals
        }
        // Small widgets have a single tap target: the master that needs attention, if any.
        .widgetURL(reports.first(where: \.needsAttention).map { DeepLink.master($0.id) })
    }

    private func rows(limits: [Int], style: FleetRow.Style) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            FittingRows(limits: limits) { limit in
                VStack(alignment: .leading, spacing: style == .detailed ? 9 : 6) {
                    ForEach(reports.prefix(limit)) { report in
                        FleetRow(report: report, style: style)
                    }
                    if reports.count > limit {
                        Text("+\(reports.count - limit) more")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }

    private var table: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            FittingRows(limits: [10, 8, 6, 4]) { limit in
                tableGrid(limit: limit)
            }
            Spacer(minLength: 0)
        }
    }

    private func tableGrid(limit: Int) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
            GridRow {
                Text("Master")
                Text("CPU")
                Text("Memory")
                Text("Instances")
                Text("Uptime")
                Text("Version")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            Divider()
                .gridCellUnsizedAxes(.horizontal)
            ForEach(reports.prefix(limit)) { report in
                GridRow {
                    Link(destination: DeepLink.master(report.id)) {
                        HStack(spacing: 6) {
                            MasterHealthGlyph(report: report)
                            Text(report.name)
                                .fontWeight(.medium)
                                .lineLimit(1)
                        }
                        // The name column takes the width the others leave.
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    if let info = report.info, info.hasSystemMetrics {
                        Meter(value: info.cpuRatio, label: info.cpuUsage < 0 ? "—" : "\(info.cpuUsage)%", tint: .blue, isFlexible: true)
                        Meter(value: info.memoryRatio, label: Format.percent(info.memoryRatio), tint: .purple, isFlexible: true)
                    } else {
                        Text(report.failure ?? "No metrics")
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .gridCellColumns(2)
                    }
                    instanceSummary(report)
                    Text(report.info.map { Format.duration(seconds: $0.uptime, compact: true) } ?? "—")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    Text(report.info.flatMap { $0.version.isEmpty ? nil : $0.version } ?? "—")
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .font(.caption)
            }
            if reports.count > limit {
                Text("+\(reports.count - limit) more")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: Pieces

    /// Drops the reachability summary, then the totals, when the widget is narrow.
    private var header: some View {
        ViewThatFits(in: .horizontal) {
            headerLine(showsReachability: true, showsTotals: true)
            headerLine(showsReachability: false, showsTotals: true)
            headerLine(showsReachability: false, showsTotals: false)
        }
    }

    private func headerLine(showsReachability: Bool, showsTotals: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "point.3.connected.trianglepath.dotted")
                .font(.caption)
                .widgetAccentable()
            Text("Masters")
                .font(.subheadline.weight(.semibold))
            if showsReachability {
                Text("\(reachable) of \(reports.count) reachable")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 6)
            if showsTotals {
                totals
            }
            RefreshButton(date: date)
        }
        .lineLimit(1)
    }

    private var totals: some View {
        HStack(spacing: 8) {
            Label {
                Text("\(running)")
            } icon: {
                StatusGlyph(status: .running)
            }
            if errors > 0 {
                Label {
                    Text("\(errors)")
                } icon: {
                    StatusGlyph(status: .error)
                }
            }
        }
        .labelStyle(.titleAndIcon)
        .font(.caption2.monospacedDigit())
        .fixedSize()
    }

    @ViewBuilder
    private func instanceSummary(_ report: MasterReport) -> some View {
        if !report.isReachable {
            Text("—")
                .foregroundStyle(.secondary)
        } else {
            HStack(spacing: 4) {
                Text("\(report.running)/\(report.instances.count)")
                    .monospacedDigit()
                if report.errors > 0 {
                    StatusGlyph(status: .error)
                    Text("\(report.errors)")
                        .monospacedDigit()
                }
            }
        }
    }
}

/// One master; opens it in the app.
private struct FleetRow: View {
    enum Style {
        /// One line: name, load and instance count.
        case line
        /// Two lines, plus CPU and memory meters when there is room.
        case detailed
    }

    var report: MasterReport
    var style: Style

    var body: some View {
        Link(destination: DeepLink.master(report.id)) {
            switch style {
            case .line:
                ViewThatFits(in: .horizontal) {
                    line(showsLoad: true)
                    line(showsLoad: false)
                }
            case .detailed:
                ViewThatFits(in: .horizontal) {
                    detailed(showsMeters: true)
                    detailed(showsMeters: false)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func line(showsLoad: Bool) -> some View {
        HStack(spacing: 6) {
            MasterHealthGlyph(report: report)
                .font(.caption)
            Text(report.name)
                .font(.caption.weight(.medium))
            Spacer(minLength: 6)
            if let failure = report.failure {
                Text(failure)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else if showsLoad {
                Text(load)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            if report.isReachable {
                instanceCount
            }
        }
        .lineLimit(1)
    }

    private func detailed(showsMeters: Bool) -> some View {
        HStack(spacing: 8) {
            MasterHealthGlyph(report: report)
                .font(.callout)
            VStack(alignment: .leading, spacing: 1) {
                Text(report.name)
                    .font(.caption.weight(.medium))
                Text(detail(includesLoad: !showsMeters))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .lineLimit(1)
            Spacer(minLength: 6)
            if showsMeters, let info = report.info, info.hasSystemMetrics {
                Meter(value: info.cpuRatio, label: info.cpuUsage < 0 ? "—" : "\(info.cpuUsage)%", tint: .blue)
                Meter(value: info.memoryRatio, label: Format.percent(info.memoryRatio), tint: .purple)
            }
            if report.isReachable {
                instanceCount
            }
        }
    }

    private var instanceCount: some View {
        Text("\(report.running)/\(report.instances.count)")
            .font(.caption.monospacedDigit())
            .frame(minWidth: 30, alignment: .trailing)
    }

    /// CPU and memory as text, e.g. `CPU 23% · Mem 40%`.
    private var load: String {
        guard let info = report.info, info.hasSystemMetrics else { return "" }
        return "CPU \(info.cpuUsage < 0 ? "—" : "\(info.cpuUsage)%") · Mem \(Format.percent(info.memoryRatio))"
    }

    private func detail(includesLoad: Bool) -> String {
        if let failure = report.failure { return failure }
        guard let info = report.info else { return "" }
        var parts: [String] = []
        if includesLoad, !load.isEmpty { parts.append(load) }
        if report.errors > 0 {
            parts.append(report.errors == 1 ? "1 error" : "\(report.errors) errors")
        } else if !info.version.isEmpty {
            parts.append(info.version)
        }
        return parts.joined(separator: " · ")
    }
}

/// A small linear meter with its value.
private struct Meter: View {
    @Environment(\.widgetRenderingMode) private var renderingMode

    var value: Double
    var label: String
    var tint: Color
    /// Grows with the space a table column offers instead of keeping a fixed width.
    var isFlexible = false

    var body: some View {
        HStack(spacing: 4) {
            Gauge(value: min(max(value, 0), 1)) { EmptyView() }
                .gaugeStyle(.accessoryLinearCapacity)
                .tint(renderingMode.tint(tint))
                .frame(minWidth: 44, maxWidth: isFlexible ? 120 : 44)
                .widgetAccentable()
            Text(label)
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 30, alignment: .trailing)
        }
    }
}
