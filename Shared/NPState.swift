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
    
    func startContinuousUpdatingServerMetadatas() {
        updateServerMetadatas()
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
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
            let serverService = ServerService()
            for server in servers {
                let serverMetadata = try await serverService.getServerInfo(baseURLString: server.url!, apiKey: server.key!)
                serverMetadatas[server.id!] = serverMetadata
            }
        }
        catch {
#if DEBUG
            print("Error Getting Server Metadata: \(error.localizedDescription)")
#endif
        }
    }
}
