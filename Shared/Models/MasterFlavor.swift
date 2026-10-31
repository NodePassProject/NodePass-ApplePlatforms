//
//  MasterFlavor.swift
//  NodePass
//
//  The two API dialects the app speaks. They share one REST + SSE contract and differ only in
//  base path, instance roles and the URL grammar of managed instances.
//

import Foundation

nonisolated enum MasterFlavor: String, Codable, CaseIterable, Hashable, Sendable {
    /// NodePass master mode (`…/api/v1`, roles `server` / `client`).
    case nodePass
    /// Nowhere OpenCtrl (`…/api/v2`, roles `portal` / `vector` / `egress`).
    case openCtrl

    var title: String {
        switch self {
        case .nodePass: "NodePass"
        case .openCtrl: "Nowhere"
        }
    }

    var controllerName: String {
        switch self {
        case .nodePass: "NodePass Master"
        case .openCtrl: "OpenCtrl"
        }
    }

    var roles: [InstanceRole] {
        switch self {
        case .nodePass: [.server, .client]
        case .openCtrl: [.portal, .vector, .egress]
        }
    }

    /// Whether `GET /openapi.json` is served.
    var publishesOpenAPI: Bool { self == .nodePass }

    /// Default role when creating a new instance.
    var defaultRole: InstanceRole { roles[0] }

    /// Guesses the flavor from the API path suffix (`/v1` → NodePass, `/v2` → OpenCtrl).
    static func infer(fromBaseURL url: URL) -> MasterFlavor? {
        let components = url.path.split(separator: "/").map(String.init)
        guard let last = components.last?.lowercased() else { return nil }
        switch last {
        case "v1": return .nodePass
        case "v2": return .openCtrl
        default: return nil
        }
    }

    /// Guesses the flavor from the roles of observed instances.
    static func infer(fromRoles roles: some Sequence<InstanceRole>) -> MasterFlavor? {
        for role in roles {
            if let flavor = role.flavor { return flavor }
        }
        return nil
    }
}
