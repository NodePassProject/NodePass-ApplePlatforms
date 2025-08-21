//
//  ServerListView.swift
//  NodePass
//
//  Created by Junhui Lou on 6/30/25.
//

import SwiftUI
import SwiftData
import Cache

fileprivate enum SortIndicator: String, CaseIterable {
    case name = "name"
    case date = "date"
    
    var title: String {
        switch(self) {
        case .name:
            return String(localized: "Name")
        case .date:
            return String(localized: "Date")
        }
    }
}

fileprivate enum SortOrder: String, CaseIterable {
    case ascending = "ascending"
    case descending = "descending"
    
    var title: String {
        switch(self) {
        case .ascending:
            return String(localized: "Ascending")
        case .descending:
            return String(localized: "Descending")
        }
    }
    
    func getDescription(sortIndicator: SortIndicator) -> String {
        switch(sortIndicator) {
        case .name:
            switch(self) {
            case .ascending:
                return String(localized: "Ascending")
            case .descending:
                return String(localized: "Descending")
            }
        case .date:
            switch(self) {
            case .ascending:
                return String(localized: "Oldest to Newest")
            case .descending:
                return String(localized: "Newest to Oldest")
            }
        }
    }
}

struct ServerListView: View {
    @Environment(NPState.self) var state
    
    @Environment(\.modelContext) private var context
    @Query private var servers: [Server]
    
    @State private var serverMetadatas: [String: ServerMetadata] = .init()
    
    @State private var sortIndicator: SortIndicator = SortIndicator(rawValue: NPCore.userDefaults.string(forKey: NPCore.Strings.NPServerSortIndicator) ?? "date")! {
        didSet {
            NPCore.userDefaults.set(sortIndicator.rawValue, forKey: NPCore.Strings.NPServerSortIndicator)
        }
    }
    @State private var sortOrder: SortOrder = SortOrder(rawValue: NPCore.userDefaults.string(forKey: NPCore.Strings.NPServerSortOrder) ?? "ascending")! {
        didSet {
            NPCore.userDefaults.set(sortOrder.rawValue, forKey: NPCore.Strings.NPServerSortOrder)
        }
    }
    
    private var sortedServers: [Server] {
        servers
            .sorted {
                switch sortIndicator {
                case .name:
                    return sortOrder == .ascending ? $0.name! < $1.name! : $0.name! > $1.name!
                case .date:
                    return sortOrder == .ascending ? $0.timestamp! < $1.timestamp! : $0.timestamp! > $1.timestamp!
                }
            }
    }
    
    @State private var searchText: String = ""
    private var filteredServers: [Server] {
        if searchText == "" {
            return sortedServers
        }
        else {
            return sortedServers.filter { $0.name!.localizedCaseInsensitiveContains(searchText) }
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
            if #available(iOS 26.0, macOS 26.0, *) {
                ToolbarSpacer(.fixed)
            }
            ToolbarItem {
                moreMenu
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
    
    private var moreMenu: some View {
        Menu("More", systemImage: "ellipsis") {
            Picker("Sort", selection: Binding(get: {
                sortIndicator
            }, set: { newValue in
                if sortIndicator == newValue {
                    switch(sortOrder) {
                    case .ascending:
                        sortOrder = .descending
                    case .descending:
                        sortOrder = .ascending
                    }
                }
                else {
                    sortIndicator = newValue
                }
            })) {
                ForEach(SortIndicator.allCases, id: \.self) { sortIndicator in
                    Button {
                        
                    } label: {
                        Text(sortIndicator.title)
                        if self.sortIndicator == sortIndicator {
                            Text(sortOrder.getDescription(sortIndicator: sortIndicator))
                        }
                    }
                    .tag(sortIndicator)
                }
            }
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
                    if let cpu = metadata.cpu, let memory = metadata.memory, let networkReceive = metadata.networkReceive, let networkTransmit = metadata.networkTransmit, let diskRead = metadata.diskRead, let diskWrite = metadata.diskWrite {
                        HStack {
                            HStack {
                                Text("CPU")
                                    .bold()
                                Text("\(String(cpu))%")
                                    .foregroundStyle(.secondary)
                            }
                            HStack {
                                Text("Memory")
                                    .bold()
                                Text("\(String(memory))%")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .font(.caption)
                        HStack {
                            Text("Network")
                                .bold()
                            HStack(spacing: 3) {
                                Text("RX")
                                Text("\(NPCore.formatBytes(networkReceive))")
                                    .foregroundStyle(.secondary)
                            }
                            HStack(spacing: 3) {
                                Text("TX")
                                Text("\(NPCore.formatBytes(networkTransmit))")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .font(.caption)
                        HStack {
                            Text("Disk")
                                .bold()
                            HStack(spacing: 3) {
                                Text("Read")
                                Text("\(NPCore.formatBytes(diskRead))")
                                    .foregroundStyle(.secondary)
                            }
                            HStack(spacing: 3) {
                                Text("Write")
                                Text("\(NPCore.formatBytes(diskWrite))")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .font(.caption)
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
