//
//  SessionStore.swift
//  NodePass
//
//  Owns one `MasterSession` per persisted master and keeps them in step with SwiftData.
//

import Foundation
import Observation

@Observable
@MainActor
final class SessionStore {
    private(set) var sessions: [String: MasterSession] = [:]
    private(set) var isActive = false

    func session(for id: String) -> MasterSession? { sessions[id] }

    /// Creates, updates and removes sessions so they mirror `masters`.
    func sync(with masters: [Server], configuration: SessionConfiguration) {
        sync(with: masters.map { ($0.snapshot, $0.flavorSetting == .automatic ? nil : $0.resolvedFlavor) }, configuration: configuration)
    }

    /// The same for snapshots, as the watch app holds them. A snapshot's flavor is the explicit
    /// setting or the API path's hint, which is exactly what a session would resolve first, so
    /// passing it as the override changes nothing.
    func sync(with snapshots: [MasterSnapshot], configuration: SessionConfiguration) {
        sync(with: snapshots.map { ($0, $0.flavor) }, configuration: configuration)
    }

    private func sync(with masters: [(snapshot: MasterSnapshot, flavorOverride: MasterFlavor?)], configuration: SessionConfiguration) {
        var seen = Set<String>()
        for (snapshot, override) in masters {
            seen.insert(snapshot.id)
            if let session = sessions[snapshot.id] {
                session.update(snapshot: snapshot, flavorOverride: override)
                if isActive {
                    if snapshot.isEnabled { session.start() } else { session.stop() }
                }
            } else {
                let session = MasterSession(snapshot: snapshot, flavorOverride: override)
                session.apply(configuration)
                sessions[snapshot.id] = session
                if isActive, snapshot.isEnabled { session.start() }
            }
        }
        for id in sessions.keys where !seen.contains(id) {
            sessions[id]?.stop()
            sessions.removeValue(forKey: id)
        }
    }

    func activate() {
        isActive = true
        for session in sessions.values where session.snapshot.isEnabled {
            session.start()
        }
    }

    func deactivate() {
        isActive = false
        for session in sessions.values { session.stop() }
    }

    func apply(_ configuration: SessionConfiguration) {
        for session in sessions.values { session.apply(configuration) }
    }
}
