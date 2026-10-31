//
//  MasterOverviewView.swift
//  NodePass Widget
//

import WidgetKit
import SwiftUI

struct MasterOverviewWidgetView: View {
    @Environment(\.widgetFamily) private var family

    var entry: MasterOverviewEntry

    var body: some View {
        content
            .containerBackground(.background, for: .widget)
    }

    @ViewBuilder
    private var content: some View {
        switch entry.content {
        case .message(let message):
            WidgetMessage(message: message)
        case .report(let report) where !report.isReachable:
            WidgetMessage(title: report.name, message: report.failure ?? "", symbolName: "bolt.horizontal.circle")
                .widgetURL(DeepLink.master(report.id))
        case .report(let report):
            MasterOverviewLayout(report: report, family: family, date: entry.date)
                .widgetURL(DeepLink.master(report.id))
        }
    }
}

/// The layouts of a reachable master, one per widget family.
struct MasterOverviewLayout: View {
    var report: MasterReport
    var family: WidgetFamily
    var date: Date

    var body: some View {
        switch family {
        case .systemSmall: small
        case .systemLarge: large
        case .systemExtraLarge: extraLarge
        default: medium
        }
    }

    // MARK: Families

    private var small: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Text(report.name)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Spacer(minLength: 0)
                MasterHealthGlyph(report: report)
                    .font(.caption)
            }
            Spacer(minLength: 0)
            if let info = report.info, info.hasSystemMetrics {
                HStack {
                    HostRings(info: info, size: 46, metrics: [.cpu, .memory])
                        .frame(maxWidth: .infinity)
                }
            } else {
                runningSummary
            }
            Spacer(minLength: 0)
            InstanceCounts(report: report)
        }
    }

    private var medium: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            if let info = report.info, info.hasSystemMetrics {
                ViewThatFits(in: .vertical) {
                    mediumRings(info, size: 50, showsFooter: true)
                    mediumRings(info, size: 44, showsFooter: true)
                    mediumRings(info, size: 44, showsFooter: false)
                }
            } else {
                instanceList(limits: [4, 3, 2], detail: .compact)
                Spacer(minLength: 0)
                footer
            }
        }
    }

    private func mediumRings(_ info: MasterInfo, size: CGFloat, showsFooter: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                HostRings(info: info, size: size)
                    .frame(maxWidth: .infinity)
            }
            if showsFooter {
                Spacer(minLength: 0)
                footer
            }
        }
    }

    private var large: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            if let info = report.info, info.hasSystemMetrics {
                HStack(alignment: .top) {
                    HostRings(info: info, size: 52)
                        .frame(maxWidth: .infinity)
                }
                Divider()
                instanceList(limits: [10, 8, 6, 4, 2], detail: .full)
            } else {
                instanceList(limits: [14, 12, 10, 8, 6, 4], detail: .full)
            }
            Spacer(minLength: 0)
            footer
        }
    }

    private var extraLarge: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                header
                if let info = report.info, info.hasSystemMetrics {
                    Grid(horizontalSpacing: 18, verticalSpacing: 12) {
                        GridRow {
                            HostRings(info: info, size: 58, metrics: [.cpu, .memory])
                        }
                        GridRow {
                            HostRings(info: info, size: 58, metrics: [.swap, .network])
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                hostFacts
                Spacer(minLength: 0)
            }
            .frame(width: 250)
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Instances")
                        .font(.caption.weight(.semibold))
                    Spacer()
                    InstanceCounts(report: report)
                }
                instanceList(limits: [14, 12, 10, 8, 6], detail: .full)
                Spacer(minLength: 0)
                HStack {
                    Spacer()
                    RefreshButton(date: date)
                }
            }
        }
    }

    // MARK: Pieces

    private var header: some View {
        HStack(spacing: 6) {
            MasterHealthGlyph(report: report)
                .font(.caption)
            Text(report.name)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            if let uptime = report.info?.uptime, uptime > 0, family != .systemExtraLarge {
                Label(Format.duration(seconds: uptime, compact: true), systemImage: "power")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if family != .systemExtraLarge {
                RefreshButton(date: date)
            }
        }
    }

    private var footer: some View {
        HStack {
            InstanceCounts(report: report)
            Spacer()
            if let version = report.info?.version, !version.isEmpty {
                Text(version)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var runningSummary: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(report.running)/\(report.instances.count)")
                .font(.system(size: 30, weight: .semibold, design: .rounded))
                .monospacedDigit()
            Text("instances running")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func instanceList(limits: [Int], detail: InstanceRow.Detail) -> some View {
        if report.instances.isEmpty {
            Text("No instances")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            FittingRows(limits: limits) { limit in
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(report.highlightedInstances(limit: limit)) { instance in
                        InstanceRow(instance: instance, masterID: report.id, detail: detail)
                    }
                    if report.instances.count > limit {
                        Text("+\(report.instances.count - limit) more")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var hostFacts: some View {
        if let info = report.info {
            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 4) {
                if info.memoryTotal > 0 {
                    fact("Memory", "\(Format.bytes(info.memoryUsed, decimals: 1)) of \(Format.bytes(info.memoryTotal, decimals: 0))")
                }
                if info.uptime > 0 {
                    fact("Uptime", Format.duration(seconds: info.uptime))
                }
                if !info.version.isEmpty {
                    fact("Version", info.version)
                }
                let system = [info.os, info.architecture].filter { !$0.isEmpty }.joined(separator: " ")
                if !system.isEmpty {
                    fact("System", system)
                }
            }
            .font(.caption2)
        }
    }

    private func fact(_ title: String, _ value: String) -> some View {
        GridRow {
            Text(title)
                .foregroundStyle(.secondary)
            Text(value)
                .monospacedDigit()
                .lineLimit(1)
        }
    }
}
