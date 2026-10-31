//
//  InstanceFilterChips.swift
//  NodePass
//
//  Toggle chips that narrow the instances of a master by status and type, with live counts.
//

import SwiftUI

struct InstanceFilterChips: View {
    var session: MasterSession
    @Binding var filter: InstanceFilter

    var body: some View {
        HStack(spacing: 6) {
            statusChip(.running, count: session.runningCount)
            statusChip(.stopped, count: session.stoppedCount)
            statusChip(.error, count: session.errorCount)
            if session.flavor.roles.count > 1 {
                ForEach(session.flavor.roles, id: \.self) { role in
                    roleChip(role)
                }
            }
            if filter.isNarrowing {
                Button("Clear Filters", systemImage: "xmark.circle.fill") {
                    withAnimation(.signal) { filter.clearNarrowing() }
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .help("Clear Filters")
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.signal, value: filter.isNarrowing)
        .sensoryFeedback(.selection, trigger: filter)
    }

    private func statusChip(_ status: InstanceStatus, count: Int) -> some View {
        let isOn = filter.statuses.contains(status)
        return Button {
            withAnimation(.signal) {
                if isOn { filter.statuses.remove(status) } else { filter.statuses.insert(status) }
            }
        } label: {
            Pill(text: "\(count) \(status.title)", tint: status.tint, prominent: isOn)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private func roleChip(_ role: InstanceRole) -> some View {
        let isOn = filter.roles.contains(role)
        let count = session.counts.byRole[role] ?? 0
        return Button {
            withAnimation(.signal) {
                if isOn { filter.roles.remove(role) } else { filter.roles.insert(role) }
            }
        } label: {
            Pill(text: "\(count) \(role.title)", tint: role.tint, prominent: isOn)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
