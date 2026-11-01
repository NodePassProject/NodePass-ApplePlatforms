//
//  HostStatusBar.swift
//  NodePass
//
//  Live host metrics of a master along the bottom of the workspace, in the spirit of Activity
//  Monitor's footer.
//

#if os(macOS)
import SwiftUI

struct HostStatusBar: View {
    var session: MasterSession

    /// How much the bar shows. The inspector can narrow the column below the full bar's width,
    /// and a bar that cannot give up width pushes a minimum onto the split view that it cannot
    /// meet; AppKit then gives up on the window's constraints and the app dies. So the bar drops
    /// detail instead, widest arrangement that fits first.
    private enum Detail {
        case full, compact, minimal
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            bar(.full)
            bar(.compact)
            bar(.minimal)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .lineLimit(1)
        .accessibilityElement(children: .contain)
    }

    private func bar(_ detail: Detail) -> some View {
        HStack(spacing: 18) {
            ConnectionIndicator(state: session.connection)
            if detail != .minimal, let info = session.info, info.hasSystemMetrics {
                separator
                metric("CPU", value: info.cpuUsage < 0 ? "—" : "\(info.cpuUsage)%") {
                    if detail == .full, session.infoHistory.count > 2 {
                        Sparkline(values: session.infoHistory.map(\.cpu), tint: .blue, maximum: 1)
                            .frame(width: 56, height: 16)
                    }
                }
                metric("Memory", value: "\(Format.bytes(info.memoryUsed, decimals: 1)) of \(Format.bytes(info.memoryTotal, decimals: 0))") {
                    if detail == .full {
                        Gauge(value: info.memoryRatio) { EmptyView() }
                            .gaugeStyle(.accessoryLinearCapacity)
                            .tint(.purple)
                            .frame(width: 48)
                    }
                }
                if detail == .full, info.swapTotal > 0 {
                    metric("Swap", value: Format.percent(info.swapRatio)) { EmptyView() }
                }
            }
            if detail != .minimal, let rate = session.networkRate {
                separator
                metric("Network", value: nil) {
                    RateLegend(received: rate.received, transmitted: rate.transmitted)
                }
            }
            if detail == .full, let info = session.info, info.uptime > 0 {
                separator
                metric("Uptime", value: Format.duration(seconds: info.uptime, compact: true)) { EmptyView() }
            }
            Spacer(minLength: 0)
            if session.hasLoadedInstances {
                instanceCounts
            }
        }
    }

    private var separator: some View {
        Divider().frame(height: 22)
    }

    private func metric(_ title: String, value: String?, @ViewBuilder accessory: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            HStack(spacing: 6) {
                if let value {
                    Text(value)
                        .font(.callout.monospacedDigit())
                }
                accessory()
            }
        }
        .fixedSize()
    }

    private var instanceCounts: some View {
        HStack(spacing: 10) {
            Label("\(session.runningCount)", systemImage: InstanceStatus.running.symbolName)
                .foregroundStyle(InstanceStatus.running.tint)
                .help("Running")
            Label("\(session.stoppedCount)", systemImage: InstanceStatus.stopped.symbolName)
                .foregroundStyle(.secondary)
                .help("Stopped")
            if session.errorCount > 0 {
                Label("\(session.errorCount)", systemImage: InstanceStatus.error.symbolName)
                    .foregroundStyle(InstanceStatus.error.tint)
                    .help("Error")
            }
        }
        .font(.callout.monospacedDigit())
        .labelStyle(.titleAndIcon)
    }
}
#endif
