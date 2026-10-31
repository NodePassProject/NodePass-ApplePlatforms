//
//  InstanceRowView.swift
//  NodePass
//

import SwiftUI

struct InstanceRowView: View {
    @Environment(AppSettings.self) private var settings

    var instance: Instance
    var isBusy: Bool
    var rate: RateSample?

    var body: some View {
        switch settings.instanceDensity {
        case .compact: compact
        case .regular: regular
        }
    }

    private var regular: some View {
        HStack(alignment: .top, spacing: 10) {
            StatusDot(status: instance.status)
                .padding(.top, 6)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(instance.displayName)
                        .font(.body.weight(.medium))
                        .lineLimit(1)
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
                Text(instance.url)
                    .font(.caption.monospaced())
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
        }
        .padding(.vertical, 3)
    }

    private var compact: some View {
        HStack(spacing: 8) {
            StatusDot(status: instance.status, size: 8)
            Text(instance.displayName)
                .font(.callout.weight(.medium))
                .lineLimit(1)
                .frame(minWidth: 60, alignment: .leading)
            Text(instance.role.title.prefix(1))
                .font(.caption2.weight(.bold))
                .foregroundStyle(instance.role.tint)
            Text(instance.url)
                .font(.caption.monospaced())
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
            } else {
                Text("↓\(Format.bytes(instance.totalReceived, decimals: 0)) ↑\(Format.bytes(instance.totalTransmitted, decimals: 0))")
            }
            if instance.ping > 0 {
                Text("\(instance.ping)ms")
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
