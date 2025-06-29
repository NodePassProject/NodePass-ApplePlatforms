//
//  ServerListView.swift
//  NodePass
//
//  Created by Junhui Lou on 6/30/25.
//

import SwiftUI
import SwiftData

struct ServerListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Server.timestamp) private var servers: [Server]
    
    @State private var isShowEditServerSheet: Bool = false
    @State var serverToEdit: Server?
    
    var body: some View {
        VStack {
            if servers.isEmpty {
                ContentUnavailableView("No Server", systemImage: "square.stack.3d.up.fill", description: Text("To add a server, tap the add server icon in the toolbar.").font(.caption))
            }
            else {
                serverList
            }
        }
        .navigationTitle("Servers")
        .toolbar {
            ToolbarItem {
                Button {
                    isShowEditServerSheet = true
                } label: {
                    Label("Add", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $isShowEditServerSheet) {
            EditServerView(server: $serverToEdit)
        }
    }
    
    private var serverList: some View {
        List {
            ForEach(servers) { server in
                NavigationLink {
                    InstanceListView(server: server)
                } label: {
                    VStack(alignment: .leading) {
                        Text(server.name!)
                        Text(server.url!)
                            .font(.caption)
                            .foregroundStyle(.gray)
                    }
                }
                .renamableAndDeletable(renameAction: {
                    serverToEdit = server
                    isShowEditServerSheet = true
                }, deleteAction: {
                    context.delete(server)
                })
            }
        }
    }
}
