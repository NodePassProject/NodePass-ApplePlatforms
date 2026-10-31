//
//  InstanceActionBar.swift
//  NodePass
//
//  Start / Stop / Restart / Reset as a row of large buttons.
//

import SwiftUI

struct InstanceActionBar: View {
    var isEnabled: (InstanceAction) -> Bool
    var perform: (InstanceAction) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(InstanceAction.allCases) { action in
                Button {
                    perform(action)
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: action.symbolName)
                            .font(.title3)
                        Text(action.title)
                            .font(.caption2)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
                .tint(action.tint)
                .disabled(!isEnabled(action))
            }
        }
    }
}

extension InstanceAction {
    var tint: Color {
        switch self {
        case .start: .green
        case .stop: .orange
        case .restart: .blue
        case .reset: .gray
        }
    }
}
