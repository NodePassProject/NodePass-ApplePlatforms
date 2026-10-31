//
//  InstanceRowView.swift
//  NodePass
//
//  One instance as a list row. The status sits on the leading edge as the signal bar; a stopped
//  instance recedes, an instance in error carries the warning glyph next to its name.
//

import SwiftUI

struct InstanceRowView: View {
    @Environment(AppSettings.self) private var settings

    var instance: Instance
    var isBusy: Bool
    var rate: RateSample?

    var body: some View {
        Group {
            switch settings.instanceDensity {
            case .compact: compact
            case .regular: regular
            }
        }
        .signalBar(instance.status.tint)
        .animation(.signal, value: instance.status)
    }

    private var regular: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                name
                RolePill(role: instance.role)
                Spacer(minLength: 4)
                if instance.restart {
                    Image(systemName: "arrow.trianglehead.clockwise")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .accessibilityLabel("Auto-restart on")
                }
                if isBusy {
                    ProgressView().controlSize(.mini)
                }
            }
            InstanceURLText(url: instance.url, masksCredential: true, font: .code(.caption))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            metrics
            if !instance.meta.tags.isEmpty {
                FlowLayout(spacing: 4) {
                    ForEach(instance.meta.sortedTags.prefix(6), id: \.key) { tag in
                        TagChip(key: tag.key, value: tag.value)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var compact: some View {
        HStack(spacing: 8) {
            name
                .font(.callout.weight(.medium))
                .frame(minWidth: 60, alignment: .leading)
            Text(instance.role.title.prefix(1))
                .font(.caption2.weight(.bold))
                .foregroundStyle(instance.role.tint)
                .accessibilityLabel(instance.role.title)
            Text(instance.endpointSummary)
                .font(.code(.caption))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 4)
            if isBusy {
                ProgressView().controlSize(.mini)
            } else {
                Text("↓\(Format.bytes(instance.totalReceived, decimals: 0)) ↑\(Format.bytes(instance.totalTransmitted, decimals: 0))")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }

    /// The name, muted for a stopped instance, with the warning glyph for one in error so the
    /// state reads from shape as well as from the signal bar's color.
    private var name: some View {
        HStack(spacing: 4) {
            if instance.status == .error {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(InstanceStatus.error.tint)
                    .accessibilityLabel("Error")
            }
            Text(instance.displayName)
                .font(.body.weight(.medium))
                .foregroundStyle(instance.status == .stopped ? .secondary : .primary)
                .lineLimit(1)
        }
    }

    private var metrics: some View {
        ViewThatFits(in: .horizontal) {
            metricsLine(showsIdentifier: settings.showInstanceIdentifiers, showsPool: true)
            metricsLine(showsIdentifier: false, showsPool: true)
            metricsLine(showsIdentifier: false, showsPool: false)
        }
    }

    private func metricsLine(showsIdentifier: Bool, showsPool: Bool) -> some View {
        HStack(spacing: 8) {
            if showsIdentifier {
                Text(instance.id)
                    .foregroundStyle(.tertiary)
            }
            Label("\(instance.tcpConnections)", systemImage: "t.square")
            Label("\(instance.udpConnections)", systemImage: "u.square")
            if let rate, rate.received + rate.transmitted > 0 {
                Label(Format.bitRate(bytesPerSecond: rate.received + rate.transmitted), systemImage: "waveform.path.ecg")
                    .foregroundStyle(.blue)
                    .contentTransition(.numericText())
            } else {
                Text("↓\(Format.bytes(instance.totalReceived, decimals: 0)) ↑\(Format.bytes(instance.totalTransmitted, decimals: 0))")
            }
            if instance.ping > 0 {
                Text("\(instance.ping) ms")
            }
            if showsPool, instance.pool > 0 {
                Label("\(instance.pool)", systemImage: "square.stack.3d.up")
            }
        }
        .font(.caption2.monospacedDigit())
        .foregroundStyle(.secondary)
        .labelStyle(.titleAndIcon)
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
    }
}
