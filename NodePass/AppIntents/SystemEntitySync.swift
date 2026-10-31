//
//  SystemEntitySync.swift
//  NodePass
//
//  Keeps the system's picture of the app's content current: masters and the instances of
//  connected masters are indexed in Spotlight, and Siri learns their names for the App Shortcut
//  phrases ("Restart my-tunnel in NodePass").
//

import AppIntents
import CoreSpotlight
import SwiftData
import SwiftUI

extension View {
    /// Donates masters and instances to Spotlight and refreshes the App Shortcut vocabulary
    /// while this view is on screen. Attached to every main window; the work is idempotent.
    func keepsSystemIndexInSync() -> some View {
        modifier(SystemEntitySyncModifier())
    }
}

private struct SystemEntitySyncModifier: ViewModifier {
    @Environment(SessionStore.self) private var sessions
    @Query(sort: \Server.timestamp) private var masters: [Server]

    func body(content: Content) -> some View {
        content.task(id: fingerprint) {
            // Instance tables settle in bursts after a (re)connect; wait for the burst to end.
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            await SystemEntityIndex.shared.update(masters: masters.map(\.snapshot), sessions: sessions)
        }
    }

    /// Changes when a master or instance appears, disappears or is renamed. Status and counters
    /// stay out of it: Spotlight does not show them, and they change constantly. The sessions'
    /// catalog fingerprints are read instead of their instance tables, so this modifier, and the
    /// window root it is attached to, are not re-evaluated by every counter update.
    private var fingerprint: [String] {
        var parts = masters.map { "\($0.id)|\($0.name)|\($0.url)|\($0.isEnabled)|\($0.flavorRawValue ?? "")" }
        for session in sessions.sessions.values where session.hasLoadedInstances {
            parts.append("\(session.id)\n\(session.catalogFingerprint)")
        }
        return parts.sorted()
    }
}

@MainActor
final class SystemEntityIndex {
    static let shared = SystemEntityIndex()

    /// What this process has indexed, so what disappears is removed again.
    private var indexedMasterIDs: Set<String> = []
    private var indexedInstanceIDs: [String: Set<String>] = [:]

    func update(masters: [MasterSnapshot], sessions: SessionStore) async {
        let index = CSSearchableIndex.default()

        let masterIDs = Set(masters.map(\.id))
        let removedMasters = indexedMasterIDs.subtracting(masterIDs)
        if !removedMasters.isEmpty {
            try? await index.deleteAppEntities(identifiedBy: Array(removedMasters), ofType: MasterEntity.self)
            for masterID in removedMasters {
                let instanceIDs = indexedInstanceIDs.removeValue(forKey: masterID) ?? []
                try? await index.deleteAppEntities(identifiedBy: instanceIDs.map { InstanceEntity.ID(masterID: masterID, instanceID: $0) }, ofType: InstanceEntity.self)
            }
        }
        try? await index.indexAppEntities(masters.map(MasterEntity.init))
        indexedMasterIDs = masterIDs

        for master in masters {
            // Only a loaded session knows the master's instances; the index keeps the rest as is.
            guard master.isEnabled, let session = sessions.session(for: master.id), session.hasLoadedInstances else { continue }
            let entity = MasterEntity(master)
            let instances = session.visibleInstances
            let current = Set(instances.map(\.id))
            let removed = (indexedInstanceIDs[master.id] ?? []).subtracting(current)
            if !removed.isEmpty {
                try? await index.deleteAppEntities(identifiedBy: removed.map { InstanceEntity.ID(masterID: master.id, instanceID: $0) }, ofType: InstanceEntity.self)
            }
            try? await index.indexAppEntities(instances.map { InstanceEntity($0, master: entity) })
            indexedInstanceIDs[master.id] = current
        }

        NodePassShortcuts.updateAppShortcutParameters()
    }
}
