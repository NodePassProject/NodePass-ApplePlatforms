//
//  ServerListView.swift
//  NodePass
//
//  Created by Junhui Lou on 6/30/25.
//

import SwiftUI
import SwiftData

struct ServerListView: View {
    @Environment(NPState.self) var state
    
    @Environment(\.modelContext) private var context
    @Query(sort: \Server.timestamp) private var servers: [Server]
    
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
                    state.isShowEditServerSheet = true
                } label: {
                    Label("Add", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $state.isShowEditServerSheet) {
            state.serverToEdit = nil
        } content: {
            EditServerView(server: $state.serverToEdit)
        }
    }
    
    private var serverList: some View {
        Form {
            ForEach(filteredServers) { server in
                NavigationLink(value: server) {
                    VStack(alignment: .leading) {
                        Text(server.name!)
                        Text(server.url!)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .editableAndDeletable(editAction: {
                    state.serverToEdit = server
                    state.isShowEditServerSheet = true
                }, deleteAction: {
                    context.delete(server)
                })
            }
        }
        .formStyle(.grouped)
    }
}
