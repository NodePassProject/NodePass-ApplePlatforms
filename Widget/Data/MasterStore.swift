//
//  MasterStore.swift
//  NodePass Widget
//
//  Masters as the extension sees them: read-only snapshots from the shared SwiftData store.
//

import Foundation
import SwiftData

@MainActor
enum MasterStore {
    /// Opened once per extension process and reused by every timeline reload.
    private static let container = Result { try NPData.makeContainer() }

    static func snapshots() throws -> [MasterSnapshot] {
        // A fresh context per read, so edits made in the app since the last reload show up.
        let context = ModelContext(try container.get())
        let descriptor = FetchDescriptor<Server>(sortBy: [SortDescriptor(\.timestamp)])
        return try context.fetch(descriptor).map(\.snapshot)
    }

    static func snapshots(ids: [String]) throws -> [MasterSnapshot] {
        let all = try snapshots()
        return ids.compactMap { id in all.first { $0.id == id } }
    }
}
