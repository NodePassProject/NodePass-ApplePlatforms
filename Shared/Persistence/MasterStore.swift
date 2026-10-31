//
//  MasterStore.swift
//  NodePass
//
//  Read access to the persisted masters for code that runs outside SwiftUI views: the App
//  Intents queries in the app and in the widget extension.
//

import Foundation
import SwiftData

@MainActor
final class MasterStore {
    private let container: Result<ModelContainer, any Error>
    private let readsMainContext: Bool

    /// Reads through the container the app already holds, so a process never mirrors CloudKit
    /// twice and unsaved edits in the main context are visible.
    init(container: ModelContainer) {
        self.container = .success(container)
        readsMainContext = true
    }

    /// Opens the shared store for an extension. The store is opened once per process; a failure
    /// surfaces on the first read instead of at launch.
    init() {
        container = Result { try NPData.makeContainer() }
        readsMainContext = false
    }

    /// Every master, oldest first.
    func snapshots() throws -> [MasterSnapshot] {
        let descriptor = FetchDescriptor<Server>(sortBy: [SortDescriptor(\.timestamp)])
        return try context().fetch(descriptor).map(\.snapshot)
    }

    /// The masters with these identifiers, in the order given. Unknown identifiers are skipped.
    func snapshots(ids: [String]) throws -> [MasterSnapshot] {
        let all = try snapshots()
        return ids.compactMap { id in all.first { $0.id == id } }
    }

    func snapshot(id: String) throws -> MasterSnapshot? {
        try snapshots(ids: [id]).first
    }

    /// The app reads its main context; an extension opens a fresh context per read so edits made
    /// in the app since the last call show up.
    private func context() throws -> ModelContext {
        let container = try container.get()
        return readsMainContext ? container.mainContext : ModelContext(container)
    }
}
