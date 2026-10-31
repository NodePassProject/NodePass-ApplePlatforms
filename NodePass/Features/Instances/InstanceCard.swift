//
//  InstanceCard.swift
//  NodePass
//
//  One instance as a card for the grid layout: the signal bar, the name and type, the endpoint,
//  a throughput sparkline and the live counts. Cards share one structure so a grid stays even.
//

#if os(iOS)
import SwiftUI

struct InstanceCard: View {
    var instance: Instance
    var isBusy: Bool
    var samples: [RateSample]
    var isSelected = false
    /// In selection mode the card shows a check mark instead of opening the instance.
    var selectionMode = false
    var isChecked = false

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: DS.Radius.panel, style: .continuous)
    }

    private var currentRate: Double {
        samples.last.map { $0.received + $0.transmitted } ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            HStack(spacing: 6) {
                if selectionMode {
                    Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(isChecked ? Color.accentColor : Color.secondary)
                        .contentTransition(.symbolEffect(.replace))
                        .transition(.scale.combined(with: .opacity))
                }
                if instance.status == .error {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(InstanceStatus.error.tint)
                        .accessibilityLabel("Error")
                }
                Text(instance.displayName)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(instance.status == .stopped ? .secondary : .primary)
                    .lineLimit(1)
                Spacer(minLength: 4)
                if isBusy {
                    ProgressView().controlSize(.mini)
                }
                RolePill(role: instance.role)
            }
            .animation(.signal, value: selectionMode)
            InstanceURLText(url: instance.url, masksCredential: true, font: .code(.caption))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            HStack(alignment: .bottom, spacing: DS.Spacing.m) {
                Sparkline(values: samples.map { $0.received + $0.transmitted }, tint: currentRate > 0 ? .blue : .secondary, maximum: nil)
                    .frame(height: 26)
                    .opacity(samples.count > 1 ? 1 : 0.25)
                Text(currentRate > 0 ? Format.bitRate(bytesPerSecond: currentRate) : "idle")
                    .font(.numeral(.subheadline))
                    .foregroundStyle(currentRate > 0 ? AnyShapeStyle(.blue) : AnyShapeStyle(.tertiary))
                    .contentTransition(.numericText())
                    .animation(.liveValue, value: currentRate)
                    .fixedSize()
            }
            HStack(spacing: 10) {
                Label("\(instance.tcpConnections)", systemImage: "t.square")
                Label("\(instance.udpConnections)", systemImage: "u.square")
                if instance.ping > 0 {
                    Label("\(instance.ping) ms", systemImage: "timer")
                }
                Spacer(minLength: 0)
                if !instance.meta.tags.isEmpty {
                    Label("\(instance.meta.tags.count)", systemImage: "tag")
                }
                if instance.restart {
                    Image(systemName: "arrow.trianglehead.clockwise")
                        .accessibilityLabel("Auto-restart on")
                }
            }
            .font(.caption2.monospacedDigit())
            .foregroundStyle(.secondary)
            .labelStyle(.titleAndIcon)
            .lineLimit(1)
        }
        .signalBar(instance.status.tint)
        .padding(DS.Spacing.l)
        .background(shape.fill(.panelBackground))
        .overlay(shape.strokeBorder(Color.accentColor, lineWidth: isSelected ? 2 : 0))
        .contentShape(shape)
        .animation(.signal, value: isSelected)
        .animation(.signal, value: instance.status)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected || isChecked ? .isSelected : [])
    }
}
#endif
