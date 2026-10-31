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
        var seen = Set<String>()
        for master in masters {
            seen.insert(master.id)
            let snapshot = master.snapshot
            let override = master.flavorSetting == .automatic ? nil : master.resolvedFlavor
            if let session = sessions[master.id] {
                session.update(snapshot: snapshot, flavorOverride: override)
                if isActive {
                    if snapshot.isEnabled { session.start() } else { session.stop() }
                }
            } else {
                let session = MasterSession(snapshot: snapshot, flavorOverride: override)
                session.apply(configuration)
                sessions[master.id] = session
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
