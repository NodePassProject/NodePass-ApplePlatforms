//
//  MasterEndpoint.swift
//  NodePass
//
//  Declarative description of every REST call the master contract offers.
//

import Foundation

nonisolated enum HTTPMethod: String, Sendable, CaseIterable, Identifiable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"

    var id: String { rawValue }
}

nonisolated struct MasterEndpoint: Sendable, Hashable {
    var method: HTTPMethod
    /// Path relative to the master base URL, starting with `/`.
    var path: String
    var queryItems: [URLQueryItem] = []
    var body: Data? = nil
    /// Public endpoints do not send the API key.
    var requiresAuthentication: Bool = true

    // MARK: Instances

    static let listInstances = MasterEndpoint(method: .get, path: "/instances")

    static func instance(_ id: String) -> MasterEndpoint {
        MasterEndpoint(method: .get, path: "/instances/\(escape(id))")
    }

    static func createInstance(url: String, alias: String?) -> MasterEndpoint {
        MasterEndpoint(method: .post, path: "/instances", body: encode(CreateInstanceBody(url: url, alias: alias)))
    }

    static func replaceInstanceURL(_ id: String, url: String) -> MasterEndpoint {
        MasterEndpoint(method: .put, path: "/instances/\(escape(id))", body: encode(URLBody(url: url)))
    }

    static func patchInstance(_ id: String, _ patch: InstancePatch) -> MasterEndpoint {
        MasterEndpoint(method: .patch, path: "/instances/\(escape(id))", body: encode(patch))
    }

    static func deleteInstance(_ id: String) -> MasterEndpoint {
        MasterEndpoint(method: .delete, path: "/instances/\(escape(id))")
    }

    // MARK: Master

    static let info = MasterEndpoint(method: .get, path: "/info")

    static func updateMasterAlias(_ alias: String) -> MasterEndpoint {
        MasterEndpoint(method: .post, path: "/info", body: encode(AliasBody(alias: alias)))
    }

    static func tcping(target: String) -> MasterEndpoint {
        MasterEndpoint(method: .get, path: "/tcping", queryItems: [URLQueryItem(name: "target", value: target)])
    }

    static let openAPISpecification = MasterEndpoint(method: .get, path: "/openapi.json", requiresAuthentication: false)

    static let events = MasterEndpoint(method: .get, path: "/events")

    // MARK: Helpers

    private static func escape(_ id: String) -> String {
        id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
    }

    private static func encode(_ value: some Encodable) -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try? encoder.encode(value)
    }

    // MARK: Bodies

    private struct CreateInstanceBody: Encodable {
        var url: String
        var alias: String?
    }

    private struct URLBody: Encodable {
        var url: String
    }

    private struct AliasBody: Encodable {
        var alias: String
    }
}

/// Partial update accepted by `PATCH /instances/{id}`. Only non-nil fields are sent.
nonisolated struct InstancePatch: Encodable, Sendable, Hashable {
    var alias: String? = nil
    var action: InstanceAction? = nil
    var restart: Bool? = nil
    var meta: Meta? = nil

    nonisolated struct Meta: Encodable, Sendable, Hashable {
        var peer: Instance.Peer? = nil
        /// Full replacement of the tag set (the master does not merge).
        var tags: [String: String]? = nil
    }

    var isEmpty: Bool { alias == nil && action == nil && restart == nil && meta == nil }

    private enum CodingKeys: String, CodingKey { case alias, action, restart, meta }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(alias, forKey: .alias)
        try c.encodeIfPresent(action?.rawValue, forKey: .action)
        try c.encodeIfPresent(restart, forKey: .restart)
        try c.encodeIfPresent(meta, forKey: .meta)
    }
}
