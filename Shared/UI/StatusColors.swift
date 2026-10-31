//
//  StatusColors.swift
//  NodePass
//
//  The colors that identify instance states and types, shared by the app and the widgets.
//

import SwiftUI

extension InstanceStatus {
    var tint: Color {
        switch self {
        case .running: .green
        case .stopped: .secondary
        case .error: .red
        case .other: .orange
        }
    }
}

extension InstanceRole {
    var tint: Color {
        switch self {
        case .server: .indigo
        case .client: .teal
        case .portal: .purple
        case .vector: .cyan
        case .egress: .orange
        case .other: .gray
        }
    }
}
