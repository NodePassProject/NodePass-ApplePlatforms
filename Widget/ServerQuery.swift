//
//  ServerQuery.swift
//  NodePass
//
//  Created by Junhui Lou on 9/19/25.
//

import AppIntents
import SwiftData

fileprivate enum SortIndicator: String {
    case name = "name"
    case date = "date"
}

fileprivate enum SortOrder: String {
    case ascending = "ascending"
    case descending = "descending"
}

struct ServerQuery: EntityQuery {
    func entities(for identifiers: [ServerEntity.ID]) async throws -> [ServerEntity] {
        let data = NPData.shared
        let dataHandler = await data.createDataHandler()()
        let servers = await dataHandler.getAllServers()
        return sortServers(servers: servers).map { ServerEntity(id: $0.id!, name: $0.name!, url: $0.url!, key: $0.key!) }
    }
    
    func suggestedEntities() async throws -> [ServerEntity] {
        let data = NPData.shared
        let dataHandler = await data.createDataHandler()()
        let servers = await dataHandler.getAllServers()
        return sortServers(servers: servers).map { ServerEntity(id: $0.id!, name: $0.name!, url: $0.url!, key: $0.key!) }
    }
    
    func defaultResult() async -> ServerEntity? {
        try? await suggestedEntities().first
    }
    
    func sortServers(servers: [Server]) -> [Server] {
        let sortIndicator: SortIndicator = SortIndicator(rawValue: NPCore.userDefaults.string(forKey: NPCore.Strings.NPServerSortIndicator) ?? "date")!
        let sortOrder: SortOrder = SortOrder(rawValue: NPCore.userDefaults.string(forKey: NPCore.Strings.NPServerSortOrder) ?? "ascending")!
        return servers
            .sorted {
                switch sortIndicator {
                case .name:
                    return sortOrder == .ascending ? $0.name! < $1.name! : $0.name! > $1.name!
                case .date:
                    return sortOrder == .ascending ? $0.timestamp! < $1.timestamp! : $0.timestamp! > $1.timestamp!
                }
            }
    }
}
