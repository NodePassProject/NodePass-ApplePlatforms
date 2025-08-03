//
//  ServerListView.swift
//  NodePass
//
//  Created by Junhui Lou on 6/30/25.
//

import SwiftUI
import SwiftData
import Cache

struct ServerListView: View {
    @Environment(NPState.self) var state
    
    @Environment(\.modelContext) private var context
    @Query(sort: \Server.timestamp) private var servers: [Server]
    
    @State private var serverMetadatas: [String: ServerMetadata] = .init()
    
    @State private var searchText: String = ""
    private var filteredServers: [Server] {
        if searchText == "" {
            return servers
        }
        else {
            return servers.filter { $0.name!.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        @Bindable var state = state
        VStack {
            if servers.isEmpty {
                ContentUnavailableView("No Server", systemImage: "square.stack.3d.up.fill", description: Text("To add a server, tap the add server icon in the toolbar.").font(.caption))
            }
            else {
                serverList
            }
        }
        .navigationTitle("Servers")
        .navigationDestination(for: Server.self) { server in
            InstanceListView(server: server)
        }
        .searchable(text: $searchText, placement: .toolbar)
        .toolbar {
            ToolbarItem {
                Button {
                    state.editServerSheetMode = .adding
                    state.isShowEditServerSheet = true
                } label: {
                    Label("Add", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $state.isShowEditServerSheet) {
            if let server = state.editServerSheetServer {
                Task {
                    await getServerMetadata(server: server)
                    state.editServerSheetServer = nil
                }
            }
            
            state.editServerSheetMode = .adding
        } content: {
            EditServerView(server: $state.editServerSheetServer)
        }
    }
    
    private var serverList: some View {
        Form {
            ForEach(filteredServers) { server in
                serverCard(server: server)
                    .onAppear {
                        serverMetadatas[server.id!] = try? NPCore.serverMetadataCacheStorage.object(forKey: server.id!)
                        Task {
                            await getServerMetadata(server: server)
                        }
                    }
            }
        }
        .formStyle(.grouped)
#if os(iOS)
        .listRowSpacing(5)
#endif
    }
    
    private func serverCard(server: Server) -> some View {
        NavigationLink(value: server) {
            let metadata = serverMetadatas[server.id!]
            VStack(alignment: .leading) {
                HStack(spacing: 10) {
                    Text(server.name!)
                    if let uptime = metadata?.uptime {
                        HStack(spacing: 3) {
                            Image(systemName: "power")
                            Text(NPCore.formatTimeInterval(seconds: uptime))
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
                Text(server.url!)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let metadata {
                    HStack(spacing: 4) {
                        Badge("\(metadata.os)/\(metadata.architecture)", backgroundColor: .purple, textColor: .white)
                        Badge(metadata.version, backgroundColor: .black, textColor: .white)
                    }
                }
            }
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                context.delete(server)
            } label: {
                Label("Delete", systemImage: "trash")
            }
            
            Button {
                state.editServerSheetMode = .editing
                state.editServerSheetServer = server
                state.isShowEditServerSheet = true
            } label: {
                Label("Edit", systemImage: "pencil")
            }
        }
        .contextMenu {
            Button {
                state.editServerSheetMode = .editing
                state.editServerSheetServer = server
                state.isShowEditServerSheet = true
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            
            let base64EncodedURL = server.url!.data(using: .utf8)!.base64EncodedString(options: .lineLength64Characters)
            let base64EncodedKey = server.key!.data(using: .utf8)!.base64EncodedString(options: .lineLength64Characters)
            ShareLink(item: "np://master?url=\(base64EncodedURL)&key=\(base64EncodedKey)") {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            
            Button(role: .destructive) {
                context.delete(server)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
    
    private func getServerMetadata(server: Server) async {
        do {
            let serverService = ServerService()
            var serverMetadata = try await serverService.getServerInfo(baseURLString: server.url!, apiKey: server.key!)
            
            serverMetadata.serverID = server.id!
            serverMetadatas[server.id!] = serverMetadata
            
            try? NPCore.serverMetadataCacheStorage.setObject(serverMetadata, forKey: server.id!)
        }
        catch {
#if DEBUG
            print("Error Getting Server Metadata: \(error.localizedDescription)")
#endif
        }
    }
}
