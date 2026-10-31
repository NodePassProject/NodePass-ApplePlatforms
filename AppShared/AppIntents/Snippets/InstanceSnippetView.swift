//
//  InstanceSnippetView.swift
//  NodePass
//

import AppIntents
import SwiftUI

struct InstanceSnippetView: View {
    var instance: InstanceEntity

    private var wire: Instance { instance.instance }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                StatusPill(status: wire.status, prominent: true)
                RolePill(role: wire.role)
                Spacer(minLength: 8)
                Label(instance.master.name, systemImage: instance.master.symbolName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(instance.name)
                    .font(.title3.weight(.semibold))
                    .lineLimit(1)
                Text(instance.endpoint)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            HStack(spacing: 14) {
                metric("TCP", "\(wire.tcpConnections)", systemImage: "t.square")
                metric("UDP", "\(wire.udpConnections)", systemImage: "u.square")
                metric("Received", Format.bytes(wire.totalReceived, decimals: 1), systemImage: "arrow.down")
                metric("Sent", Format.bytes(wire.totalTransmitted, decimals: 1), systemImage: "arrow.up")
                if wire.ping > 0 {
                    metric("Latency", "\(wire.ping) ms", systemImage: "timer")
                }
            }

            HStack(spacing: 8) {
                if wire.status == .running {
                    Button(intent: StopInstanceIntent(instance: instance)) {
                        Label("Stop", systemImage: "stop.fill")
                    }
                    .tint(.orange)
                } else {
                    Button(intent: StartInstanceIntent(instance: instance)) {
                        Label("Start", systemImage: "play.fill")
                    }
                    .tint(.green)
                }
                Button(intent: RestartInstanceIntent(instance: instance)) {
                    Label("Restart", systemImage: "arrow.clockwise")
                }
                .tint(.blue)
                Spacer()
                Button(intent: OpenInstanceIntent(target: instance)) {
                    Label("Open", systemImage: "arrow.up.forward.app")
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding()
    }

    private func metric(_ title: String, _ value: String, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(title, systemImage: systemImage)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout.weight(.medium).monospacedDigit())
        }
        .lineLimit(1)
    }
}
