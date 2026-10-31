//
//  MasterEntity.swift
//  NodePass Widget
//
//  Masters as App Intents entities, for choosing them in widget settings.
//

import AppIntents

struct MasterEntity: AppEntity {
    let id: String
    let name: String

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Master"
    static let defaultQuery = MasterQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    init(id: String, name: String) {
        self.id = id
        self.name = name
    }

    init(_ snapshot: MasterSnapshot) {
        self.init(id: snapshot.id, name: snapshot.name)
    }
}

struct MasterQuery: EntityQuery {
    func entities(for identifiers: [MasterEntity.ID]) async throws -> [MasterEntity] {
        try await MasterStore.snapshots(ids: identifiers).map(MasterEntity.init)
    }

    func suggestedEntities() async throws -> [MasterEntity] {
        try await MasterStore.snapshots().map(MasterEntity.init)
    }

    func defaultResult() async -> MasterEntity? {
        try? await suggestedEntities().first
    }
}
