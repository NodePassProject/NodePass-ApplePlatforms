//
//  MasterStatusSnippetView.swift
//  NodePass
//

import AppIntents
import SwiftUI

struct MasterStatusSnippetView: View {
    var status: MasterStatus.Report

    init(report: MasterStatus.Report) {
        status = report
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: status.master.symbolName)
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(status.master.name)
                        .font(.title3.weight(.semibold))
                        .lineLimit(1)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                Pill(
                    text: status.isReachable ? "Online" : "Offline",
                    tint: status.isReachable ? .green : .red,
                    systemImage: status.isReachable ? "checkmark" : "bolt.horizontal",
                    prominent: true
                )
            }

            if status.isReachable {
                HStack(spacing: 10) {
                    MetricTile(title: "Running", value: "\(status.runningCount)", systemImage: "play.circle.fill", tint: .green)
                    MetricTile(title: "Stopped", value: "\(status.stoppedCount)", systemImage: "stop.circle.fill", tint: .secondary)
                    MetricTile(title: "Error", value: "\(status.errorCount)", systemImage: "exclamationmark.triangle.fill", tint: status.errorCount > 0 ? .red : .secondary)
                }
                if status.cpuUsage != nil || status.memoryUsage != nil || status.uptime != nil {
                    HStack(alignment: .top, spacing: 24) {
                        if let cpu = status.cpuUsage {
                            Gauge(value: Double(cpu) / 100) {
                                Text("CPU")
                            } currentValueLabel: {
                                Text("\(cpu)%")
                            }
                            .gaugeStyle(RingGaugeStyle(tint: .blue, size: 52))
                        }
                        if let memory = status.memoryUsage {
                            Gauge(value: Double(memory) / 100) {
                                Text("Memory")
                            } currentValueLabel: {
                                Text("\(memory)%")
                            }
                            .gaugeStyle(RingGaugeStyle(tint: .purple, size: 52))
                        }
                        if let uptime = status.uptime {
                            VStack(spacing: 6) {
                                Text(Format.duration(seconds: UInt64(max(0, uptime.converted(to: .seconds).value))))
                                    .font(.system(.headline, design: .rounded))
                                    .monospacedDigit()
                                    .frame(height: 52)
                                Text("Uptime")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                    }
                }
            } else if let problem = status.problem {
                InlineMessage(text: problem, style: .error)
            }

            HStack {
                Spacer()
                Button(intent: OpenMasterIntent(target: status.master)) {
                    Label("Open in NodePass", systemImage: "arrow.up.forward.app")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding()
    }

    private var detail: String {
        var parts: [String] = []
        if let version = status.version {
            parts.append([status.master.flavor?.title, version].compactMap { $0 }.joined(separator: " "))
        }
        parts.append(status.hostname ?? status.master.host)
        return parts.joined(separator: " · ")
    }
}
