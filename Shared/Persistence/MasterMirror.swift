//
//  MasterMirror.swift
//  NodePass
//
//  The masters as they travel from iPhone to Apple Watch. The phone is the source of truth: it
//  sends every saved master (with its API key) through Watch Connectivity whenever the list
//  changes, and the watch keeps the last payload in the App Group, where the watch app and its
//  widgets read it. Records are never created on the watch, so identifiers stay the ones CloudKit
//  syncs between iPhone, iPad and Mac, and a shortcut built on any device resolves on the watch.
//

import Foundation

/// What one transfer carries.
nonisolated struct MasterMirrorPayload: Codable, Hashable, Sendable {
    /// Bumped when the encoding changes incompatibly; a receiver ignores versions it does not know.
    static let formatVersion = 1

    /// Key of the encoded payload in an application context, a message or a reply.
    static let payloadKey = "masters"
    /// Key and value of the message the watch sends to ask for the current list.
    static let requestKey = "request"
    static let requestMasters = "masters"

    var version = formatVersion
    var masters: [MasterSnapshot]
    var sentAt: Date

    init(masters: [MasterSnapshot], sentAt: Date = .now) {
        self.masters = masters
        self.sentAt = sentAt
    }

    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }

    static func decode(_ data: Data) throws -> MasterMirrorPayload {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(MasterMirrorPayload.self, from: data)
    }

    /// The Watch Connectivity dictionary form. Only property-list types travel, so the payload
    /// goes as one `Data` value.
    func message() throws -> [String: Any] {
        [Self.payloadKey: try encoded()]
    }

    /// The payload in a received dictionary, if it holds one this build understands.
    static func payload(from message: [String: Any]) -> MasterMirrorPayload? {
        guard let data = message[payloadKey] as? Data,
              let payload = try? decode(data),
              payload.version == formatVersion else { return nil }
        return payload
    }

    /// The request the watch sends when it wants the list now.
    static var request: [String: Any] {
        [requestKey: requestMasters]
    }

    static func isRequest(_ message: [String: Any]) -> Bool {
        message[requestKey] as? String == requestMasters
    }
}

#if os(watchOS)
import Observation

/// The watch's copy of the iPhone's masters, persisted in the App Group so the widget extension
/// reads the same list. The watch app owns `shared`; the widget reads the stored list directly.
@Observable
@MainActor
final class MasterMirror {
    static let shared = MasterMirror()

    nonisolated private static let payloadKey = "NPMirroredMasters"

    private(set) var snapshots: [MasterSnapshot]
    /// When the phone sent what is stored; `nil` until the first payload arrives.
    private(set) var receivedAt: Date?

    private let defaults: UserDefaults

    init(defaults: UserDefaults = NPCore.userDefaults) {
        self.defaults = defaults
        let stored = Self.storedPayload(defaults: defaults)
        snapshots = stored?.masters ?? []
        receivedAt = stored?.sentAt
    }

    var isEmpty: Bool { snapshots.isEmpty }

    func snapshot(id: String) -> MasterSnapshot? {
        snapshots.first { $0.id == id }
    }

    /// Stores a payload from the phone. Older payloads than the stored one are ignored, since a
    /// reply and an application context can arrive out of order. Returns whether the list changed.
    @discardableResult
    func replace(with payload: MasterMirrorPayload) -> Bool {
        if let receivedAt, payload.sentAt < receivedAt { return false }
        receivedAt = payload.sentAt
        if let data = try? payload.encoded() {
            defaults.set(data, forKey: Self.payloadKey)
        }
        guard payload.masters != snapshots else { return false }
        snapshots = payload.masters
        return true
    }

    /// The stored list, read fresh. For processes that do not observe the mirror (the widget).
    nonisolated static func storedSnapshots(defaults: UserDefaults = NPCore.userDefaults) -> [MasterSnapshot] {
        storedPayload(defaults: defaults)?.masters ?? []
    }

    nonisolated private static func storedPayload(defaults: UserDefaults) -> MasterMirrorPayload? {
        guard let data = defaults.data(forKey: payloadKey) else { return nil }
        return try? MasterMirrorPayload.decode(data)
    }
}
#endif
