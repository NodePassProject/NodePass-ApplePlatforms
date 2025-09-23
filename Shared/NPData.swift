//
//  NPData.swift
//  NodePass
//
//  Created by Junhui Lou on 9/22/25.
//

import Foundation
import SwiftData

final class NPData: Sendable {
    static let shared = NPData()
    
    let sharedModelContainer: ModelContainer = {
        let schema = Schema([Service.self, Server.self])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            groupContainer: ModelConfiguration.GroupContainer.identifier("group.com.argsment.NodePass"),
            cloudKitDatabase: ModelConfiguration.CloudKitDatabase.automatic)
        
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    func createDataHandler() -> @Sendable () async -> NPDataHandler {
      let container = sharedModelContainer
      return { NPDataHandler(modelContainer: container) }
    }
}

@ModelActor
actor NPDataHandler {
    func getAllServers() -> [Server] {
        do {
            return try modelContext.fetch(FetchDescriptor<Server>(predicate: nil))
        }
        catch {
#if DEBUG
            print("Error Fetching Servers: \(error.localizedDescription)")
#endif
            return []
        }
    }
}
