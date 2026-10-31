//
//  Entities+Spotlight.swift
//  NodePass
//
//  Masters and instances in the Spotlight index, so searching a name opens it in the app. The
//  app donates them (`SystemEntitySync`); these conformances describe what Spotlight shows and let
//  it ask for a refresh.
//

import AppIntents
import CoreSpotlight

extension MasterEntity: IndexedEntity {
    var attributeSet: CSSearchableItemAttributeSet {
        let attributes = defaultAttributeSet
        attributes.contentDescription = [flavor?.title, host].compactMap { $0 }.joined(separator: " · ")
        attributes.keywords = [host, flavor?.title, "master"].compactMap { $0 }
        return attributes
    }
}

extension MasterQuery: nonisolated IndexedEntityQuery {
    nonisolated func reindexEntities(for identifiers: [MasterEntity.ID], indexDescription: CSSearchableIndexDescription) async throws {
        try await CSSearchableIndex.default().indexAppEntities(try await entities(for: identifiers))
    }

    nonisolated func reindexAllEntities(indexDescription: CSSearchableIndexDescription) async throws {
        try await CSSearchableIndex.default().indexAppEntities(try await allEntities())
    }
}

extension InstanceEntity: IndexedEntity {
    var attributeSet: CSSearchableItemAttributeSet {
        let attributes = defaultAttributeSet
        attributes.contentDescription = "\(role.title) on \(master.name) · \(endpoint)"
        attributes.keywords = [identifier, master.name, role.title, "instance"] + tags
        return attributes
    }
}

extension InstanceQuery: nonisolated IndexedEntityQuery {
    nonisolated func reindexEntities(for identifiers: [InstanceEntity.ID], indexDescription: CSSearchableIndexDescription) async throws {
        try await CSSearchableIndex.default().indexAppEntities(try await entities(for: identifiers))
    }

    nonisolated func reindexAllEntities(indexDescription: CSSearchableIndexDescription) async throws {
        try await CSSearchableIndex.default().indexAppEntities(try await allEntities())
    }
}
