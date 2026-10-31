//
//  RoleSelector.swift
//  NodePass
//
//  The instance type as a row of tiles: icon and name, the chosen one in the role's tint, with
//  the role's one-line summary below. Replaces a segmented picker where the choice deserves room.
//

import SwiftUI

struct RoleSelector: View {
    var roles: [InstanceRole]
    @Binding var selection: InstanceRole

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            HStack(spacing: DS.Spacing.s) {
                ForEach(roles, id: \.self) { role in
                    tile(role)
                }
            }
            Text(selection.summary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.opacity)
                .animation(.signal, value: selection)
        }
        .sensoryFeedback(.selection, trigger: selection)
    }

    private func tile(_ role: InstanceRole) -> some View {
        let isSelected = role == selection
        let shape = RoundedRectangle(cornerRadius: DS.Radius.tile, style: .continuous)
        return Button {
            withAnimation(.signal) { selection = role }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: role.symbolName)
                    .font(.title3)
                    .symbolVariant(isSelected ? .fill : .none)
                Text(role.title)
                    .font(.subheadline.weight(.medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .foregroundStyle(isSelected ? AnyShapeStyle(role.tint) : AnyShapeStyle(.secondary))
            .background {
                shape.fill(isSelected ? AnyShapeStyle(role.tint.opacity(0.14)) : AnyShapeStyle(.tileBackground))
            }
            .overlay {
                shape.strokeBorder(role.tint, lineWidth: isSelected ? 1.5 : 0)
            }
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(role.title)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
