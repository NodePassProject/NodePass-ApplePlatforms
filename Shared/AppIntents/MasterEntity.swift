//
//  MasterEntity.swift
//  NodePass
//
//  A saved master as an App Intents entity: what Shortcuts, Siri, Spotlight and widget settings
//  pass around. Compiled into the app and the widget extension; each registers a `MasterStore`
//  with `AppDependencyManager` at launch.
//

import AppIntents
import Foundation

nonisolated struct MasterEntity: AppEntity {
    /// What the entity exposes, copied out of the record so the API key stays behind.
    nonisolated struct Details: Hashable, Sendable {
        var name: String
        var host: String
        var apiURL: URL?
        var flavor: MasterFlavor?
        var isEnabled: Bool
    }

    static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: "Master",
        numericFormat: "\(placeholder: .int) masters"
    )

    static let defaultQuery = MasterQuery()

    /// The persisted record's identifier. It follows the user through CloudKit, so a shortcut
    /// built on one device resolves on the others.
    let id: String
    let details: Details

    @ComputedProperty(title: "Name")
    var name: String { details.name }

    @ComputedProperty(title: "Host")
    var host: String { details.host }

    @ComputedProperty(title: "API URL")
    var apiURL: URL? { details.apiURL }

    @ComputedProperty(title: "Flavor")
    var flavor: MasterFlavor? { details.flavor }

    @ComputedProperty(title: "Enabled")
    var isEnabled: Bool { details.isEnabled }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(name)",
            subtitle: "\(host)",
            image: .init(systemName: symbolName)
        )
    }

    var symbolName: String {
        flavor == .openCtrl ? "circle.hexagongrid" : "server.rack"
    }

    init(_ snapshot: MasterSnapshot) {
        id = snapshot.id
        details = Details(
            name: snapshot.name,
            host: snapshot.host ?? snapshot.url,
            apiURL: snapshot.credentials?.baseURL,
            flavor: snapshot.flavor,
            isEnabled: snapshot.isEnabled
        )
    }
}

struct MasterQuery: nonisolated EntityQuery, nonisolated EntityStringQuery, nonisolated EnumerableEntityQuery {
    @Dependency private var store: MasterStore

    nonisolated init() {}

    @MainActor
    func entities(for identifiers: [MasterEntity.ID]) async throws -> [MasterEntity] {
        try store.snapshots(ids: identifiers).map(MasterEntity.init)
    }

    @MainActor
    func entities(matching string: String) async throws -> [MasterEntity] {
        try store.snapshots()
            .filter { $0.name.localizedCaseInsensitiveContains(string) || $0.url.localizedCaseInsensitiveContains(string) }
            .map(MasterEntity.init)
    }

    @MainActor
    func allEntities() async throws -> [MasterEntity] {
        try store.snapshots().map(MasterEntity.init)
    }

    @MainActor
    func suggestedEntities() async throws -> [MasterEntity] {
        try await allEntities()
    }

    /// The first enabled master, so a one-master setup never has to pick.
    @MainActor
    func defaultResult() async -> MasterEntity? {
        let all = try? await allEntities()
        return all?.first(where: \.isEnabled) ?? all?.first
    }

    nonisolated static var findIntentDescription: IntentDescription? {
        IntentDescription("Finds saved masters by name, host, flavor or whether they are enabled.", categoryName: "Masters")
    }
}
