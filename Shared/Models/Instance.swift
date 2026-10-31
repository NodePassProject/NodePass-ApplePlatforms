//
//  Instance.swift
//  NodePass
//
//  Wire representation of a managed instance as returned by `/instances`.
//  Decoding is lenient: every field has a default so older or partial masters still parse.
//

import Foundation

nonisolated struct Instance: Codable, Hashable, Identifiable, Sendable {
    var id: String
    var alias: String = ""
    var role: InstanceRole = .other("")
    var status: InstanceStatus = .other("")
    var url: String = ""
    /// Fully resolved configuration URL (instance URL + master defaults).
    var config: String = ""
    /// Auto-restart policy.
    var restart: Bool = false
    var meta: Meta = Meta()
    var mode: Int = 0
    /// Health-check latency in milliseconds (0 when unknown).
    var ping: Int = 0
    /// Current connection pool size.
    var pool: Int = 0
    var tcpConnections: Int = 0
    var udpConnections: Int = 0
    var tcpReceived: UInt64 = 0
    var tcpTransmitted: UInt64 = 0
    var udpReceived: UInt64 = 0
    var udpTransmitted: UInt64 = 0

    nonisolated struct Meta: Codable, Hashable, Sendable {
        var peer: Peer = Peer()
        var tags: [String: String] = [:]

        init(peer: Peer = Peer(), tags: [String: String] = [:]) {
            self.peer = peer
            self.tags = tags
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            peer = try container.decodeIfPresent(Peer.self, forKey: .peer) ?? Peer()
            tags = try container.decodeIfPresent([String: String].self, forKey: .tags) ?? [:]
        }

        var isEmpty: Bool { peer.isEmpty && tags.isEmpty }

        /// Tags sorted by key for stable presentation.
        var sortedTags: [(key: String, value: String)] {
            tags.sorted { $0.key.localizedStandardCompare($1.key) == .orderedAscending }.map { ($0.key, $0.value) }
        }
    }

    nonisolated struct Peer: Codable, Hashable, Sendable {
        var sid: String = ""
        var type: String = ""
        var alias: String = ""

        init(sid: String = "", type: String = "", alias: String = "") {
            self.sid = sid
            self.type = type
            self.alias = alias
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            sid = try container.decodeIfPresent(String.self, forKey: .sid) ?? ""
            type = try container.decodeIfPresent(String.self, forKey: .type) ?? ""
            alias = try container.decodeIfPresent(String.self, forKey: .alias) ?? ""
        }

        var isEmpty: Bool { sid.isEmpty && type.isEmpty && alias.isEmpty }
    }

    enum CodingKeys: String, CodingKey {
        case id, alias, status, url, config, restart, meta, mode, ping, pool
        case role = "type"
        case tcpConnections = "tcps"
        case udpConnections = "udps"
        case tcpReceived = "tcprx"
        case tcpTransmitted = "tcptx"
        case udpReceived = "udprx"
        case udpTransmitted = "udptx"
    }

    init(id: String) {
        self.id = id
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        alias = try container.decodeIfPresent(String.self, forKey: .alias) ?? ""
        role = try container.decodeIfPresent(InstanceRole.self, forKey: .role) ?? .other("")
        status = try container.decodeIfPresent(InstanceStatus.self, forKey: .status) ?? .other("")
        url = try container.decodeIfPresent(String.self, forKey: .url) ?? ""
        config = try container.decodeIfPresent(String.self, forKey: .config) ?? ""
        restart = try container.decodeIfPresent(Bool.self, forKey: .restart) ?? false
        meta = try container.decodeIfPresent(Meta.self, forKey: .meta) ?? Meta()
        mode = try container.decodeIfPresent(Int.self, forKey: .mode) ?? 0
        ping = try container.decodeIfPresent(Int.self, forKey: .ping) ?? 0
        pool = try container.decodeIfPresent(Int.self, forKey: .pool) ?? 0
        tcpConnections = try container.decodeIfPresent(Int.self, forKey: .tcpConnections) ?? 0
        udpConnections = try container.decodeIfPresent(Int.self, forKey: .udpConnections) ?? 0
        tcpReceived = try container.decodeIfPresent(UInt64.self, forKey: .tcpReceived) ?? 0
        tcpTransmitted = try container.decodeIfPresent(UInt64.self, forKey: .tcpTransmitted) ?? 0
        udpReceived = try container.decodeIfPresent(UInt64.self, forKey: .udpReceived) ?? 0
        udpTransmitted = try container.decodeIfPresent(UInt64.self, forKey: .udpTransmitted) ?? 0
    }

    // MARK: Derived

    /// The special pseudo-instance that carries the master's API key.
    var isAPIKeyHolder: Bool { id == NPCore.apiKeyInstanceID }

    var displayName: String { alias.isEmpty ? id : alias }

    var totalReceived: UInt64 { tcpReceived &+ udpReceived }
    var totalTransmitted: UInt64 { tcpTransmitted &+ udpTransmitted }
    var totalConnections: Int { tcpConnections + udpConnections }

    /// Structured view of `url`, if it parses.
    var parsedURL: InstanceURL? { try? InstanceURL(parsing: url) }

    /// Structured view of `config`, if it parses.
    var parsedConfig: InstanceURL? { try? InstanceURL(parsing: config) }

    /// Text searched by the instance list filter.
    var searchableText: String {
        var parts = [id, alias, url, role.rawValue, status.rawValue]
        for (key, value) in meta.tags {
            parts.append(key)
            parts.append(value)
        }
        if !meta.peer.alias.isEmpty { parts.append(meta.peer.alias) }
        return parts.joined(separator: " ")
    }
}
