//
//  InstanceRole.swift
//  NodePass
//
//  The `type` of a managed instance, which is also the scheme of its URL.
//

import Foundation

nonisolated enum InstanceRole: Hashable, Sendable, Codable, CustomStringConvertible {
    // NodePass
    case server
    case client
    // Nowhere
    case portal
    case vector
    case egress
    // Forward compatibility
    case other(String)

    init(rawValue: String) {
        switch rawValue.lowercased() {
        case "server": self = .server
        case "client": self = .client
        case "portal": self = .portal
        case "vector": self = .vector
        case "egress": self = .egress
        default: self = .other(rawValue)
        }
    }

    var rawValue: String {
        switch self {
        case .server: "server"
        case .client: "client"
        case .portal: "portal"
        case .vector: "vector"
        case .egress: "egress"
        case .other(let value): value
        }
    }

    var description: String { rawValue }

    var title: String {
        switch self {
        case .server: "Server"
        case .client: "Client"
        case .portal: "Portal"
        case .vector: "Vector"
        case .egress: "Egress"
        case .other(let value): value.isEmpty ? "Unknown" : value.capitalized
        }
    }

    var summary: String {
        switch self {
        case .server: "Listens on the tunnel address and bridges traffic to or from the target."
        case .client: "Connects to a server's tunnel address, or forwards locally in single-end mode."
        case .portal: "Accepts Vector and Egress connections over TLS or QUIC and chooses the exit."
        case .vector: "Exposes a local SOCKS5 ingress and carries flows to a Portal."
        case .egress: "Registers with a Portal and dials targets from a remote network."
        case .other: "Unrecognized instance type."
        }
    }

    var symbolName: String {
        switch self {
        case .server: "server.rack"
        case .client: "laptopcomputer"
        case .portal: "door.left.hand.open"
        case .vector: "arrow.up.right.circle"
        case .egress: "arrow.uturn.right.circle"
        case .other: "questionmark.circle"
        }
    }

    var flavor: MasterFlavor? {
        switch self {
        case .server, .client: .nodePass
        case .portal, .vector, .egress: .openCtrl
        case .other: nil
        }
    }

    var isKnown: Bool {
        if case .other = self { return false }
        return true
    }

    static let nodePassRoles: [InstanceRole] = [.server, .client]
    static let nowhereRoles: [InstanceRole] = [.portal, .vector, .egress]
    static let knownRoles: [InstanceRole] = nodePassRoles + nowhereRoles

    // MARK: Codable

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.init(rawValue: try container.decode(String.self))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
