//
//  InstanceActionBar.swift
//  NodePass
//
//  Start / Stop / Restart / Reset as a row of glass buttons, each in the action's tint.
//

import SwiftUI

struct InstanceActionBar: View, Equatable {
    /// The actions that make sense right now; the rest are shown disabled.
    var enabledActions: Set<InstanceAction>
    var perform: (InstanceAction) -> Void

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.enabledActions == rhs.enabledActions
    }

    var body: some View {
        GlassEffectContainer(spacing: DS.Spacing.s) {
            HStack(spacing: DS.Spacing.s) {
                ForEach(InstanceAction.allCases) { action in
                    Button {
                        perform(action)
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: action.symbolName)
                                .font(.title3.weight(.medium))
                            Text(action.title)
                                .font(.caption2.weight(.medium))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.glass)
                    .tint(action.tint)
                    .disabled(!enabledActions.contains(action))
                    .accessibilityLabel(action.title)
                }
            }
        }
    }
}

extension InstanceAction {
    /// The actions applicable to an instance in `status`, none while an operation is in flight.
    static func applicable(to status: InstanceStatus, isBusy: Bool) -> Set<InstanceAction> {
        isBusy ? [] : Set(allCases.filter { $0.isApplicable(to: status) })
    }

    var tint: Color {
        switch self {
        case .start: .green
        case .stop: .orange
        case .restart: .blue
        case .reset: .gray
        }
    }
}
