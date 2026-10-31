//
//  InstanceEnums.swift
//  NodePass
//
//  Instance status and type as values Shortcuts can filter on. The wire enums keep unknown
//  values as text for forward compatibility; these fold them into a fixed set of cases.
//

import AppIntents

nonisolated enum InstanceStatusKind: String, AppEnum {
    case running
    case stopped
    case error
    case unknown

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Instance Status")

    static let caseDisplayRepresentations: [InstanceStatusKind: DisplayRepresentation] = [
        .running: DisplayRepresentation(title: "Running", image: .init(systemName: "play.circle.fill")),
        .stopped: DisplayRepresentation(title: "Stopped", image: .init(systemName: "stop.circle.fill")),
        .error: DisplayRepresentation(title: "Error", image: .init(systemName: "exclamationmark.triangle.fill")),
        .unknown: DisplayRepresentation(title: "Unknown", image: .init(systemName: "questionmark.circle.fill")),
    ]

    init(_ status: InstanceStatus) {
        switch status {
        case .running: self = .running
        case .stopped: self = .stopped
        case .error: self = .error
        case .other: self = .unknown
        }
    }

    /// The wire status this case stands for, so the app's colors and symbols apply.
    var status: InstanceStatus {
        switch self {
        case .running: .running
        case .stopped: .stopped
        case .error: .error
        case .unknown: .other("")
        }
    }

    var title: String { status.title }
    var symbolName: String { status.symbolName }
}

nonisolated enum InstanceRoleKind: String, AppEnum {
    case server
    case client
    case portal
    case vector
    case egress
    case other

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Instance Type")

    static let caseDisplayRepresentations: [InstanceRoleKind: DisplayRepresentation] = [
        .server: DisplayRepresentation(title: "Server", subtitle: "NodePass", image: .init(systemName: "server.rack")),
        .client: DisplayRepresentation(title: "Client", subtitle: "NodePass", image: .init(systemName: "laptopcomputer")),
        .portal: DisplayRepresentation(title: "Portal", subtitle: "Nowhere", image: .init(systemName: "door.left.hand.open")),
        .vector: DisplayRepresentation(title: "Vector", subtitle: "Nowhere", image: .init(systemName: "arrow.up.right.circle")),
        .egress: DisplayRepresentation(title: "Egress", subtitle: "Nowhere", image: .init(systemName: "arrow.uturn.right.circle")),
        .other: DisplayRepresentation(title: "Other", image: .init(systemName: "questionmark.circle")),
    ]

    init(_ role: InstanceRole) {
        switch role {
        case .server: self = .server
        case .client: self = .client
        case .portal: self = .portal
        case .vector: self = .vector
        case .egress: self = .egress
        case .other: self = .other
        }
    }

    var role: InstanceRole {
        switch self {
        case .server: .server
        case .client: .client
        case .portal: .portal
        case .vector: .vector
        case .egress: .egress
        case .other: .other("")
        }
    }

    var title: String { self == .other ? "Other" : role.title }
}
