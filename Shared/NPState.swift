//
//  NPState.swift
//  NodePass
//
//  Created by Junhui Lou on 6/28/25.
//

import SwiftUI
import Observation

@Observable
class NPState {
    // Tab
    var tab: MainTab = .services
    
    // Navigation
    var pathServices: NavigationPath = .init()
    var pathServers: NavigationPath = .init()
    
    // Edit Server Sheet
    var isShowEditServerSheet: Bool = false
    var editServerSheetMode: EditServerSheetMode = .adding
    var editServerSheetServer: Server?
    
    // Metadata of Servers
    var serverMetadatas: [String: ServerMetadata] = .init()
    private var timer: Timer?
    
    func modifyContinuousUpdatingServerMetadataTimerInterval(to interval: Double) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.updateServerMetadatas()
        }
    }
    
    func startContinuousUpdatingServerMetadatas() {
        updateServerMetadatas()
        let interval = 1 / NPCore.serverMetadataUpdatingRate
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.updateServerMetadatas()
        }
    }
    
    func updateServerMetadatas() {
        Task {
            let data = NPData.shared
            let dataHandler = await data.createDataHandler()()
            let servers = await dataHandler.getAllServers()
            await getServerMetadatas(servers: servers)
        }
    }
    
    private func getServerMetadatas(servers: [Server]) async {
        do {
            try await withThrowingTaskGroup(of: (String, ServerMetadata).self) { group in
                for server in servers {
                    group.addTask {
                        let serverService = await ServerService()
                        let metadata = try await serverService.getServerInfo(baseURLString: server.url, apiKey: server.key)
                        return (server.id, metadata)
                    }
                }
                
                for try await (serverId, metadata) in group {
                    serverMetadatas[serverId] = metadata
                }
            }
        }
        catch {
    #if DEBUG
            print("Error Getting Server Metadata: \(error.localizedDescription)")
    #endif
        }
    }
}
