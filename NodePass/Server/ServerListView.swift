//
//  ServerListView.swift
//  NodePass
//
//  Created by Junhui Lou on 6/30/25.
//

import SwiftUI
import SwiftData
import Combine

fileprivate enum SortIndicator: String, CaseIterable {
    case name = "name"
    case date = "date"
    
    var title: String {
        switch(self) {
        case .name:
            return "Name"
        case .date:
            return "Date"
        }
    }
}

fileprivate enum SortOrder: String, CaseIterable {
    case ascending = "ascending"
    case descending = "descending"
    
    var title: String {
        switch(self) {
        case .ascending:
            return "Ascending"
        case .descending:
            return "Descending"
        }
    }
    
    func getDescription(sortIndicator: SortIndicator) -> String {
        switch(sortIndicator) {
        case .name:
            switch(self) {
            case .ascending:
                return "Ascending"
            case .descending:
                return "Descending"
            }
        case .date:
            switch(self) {
            case .ascending:
                return "Oldest to Newest"
            case .descending:
                return "Newest to Oldest"
            }
        }
    }
}

struct ServerListView: View {
    @Environment(NPState.self) var state
    
    @Environment(\.modelContext) private var context
    @Query private var servers: [Server]
    
    private let columns: [GridItem] = [GridItem(.adaptive(minimum: 320, maximum: 450))]
    
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
                    return sortOrder == .ascending ? $0.name < $1.name : $0.name > $1.name
                case .date:
                    return sortOrder == .ascending ? $0.timestamp < $1.timestamp : $0.timestamp > $1.timestamp
                }
            }
    }
    
    @State private var searchText: String = ""
    private var filteredServers: [Server] {
        if searchText == "" {
            return sortedServers
        }
        else {
            return sortedServers.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    @State private var isShowDeleteServerAlert: Bool = false
    @State private var serverToDelete: Server?
    
    var body: some View {
        @Bindable var state = state
        ZStack {
            BackgroundColorfulView.shared
            
            if servers.isEmpty {
                ContentUnavailableView("No Server", systemImage: "square.stack.3d.up.fill", description: Text("To add a server, tap the add server icon in the toolbar.").font(.caption))
            }
            else {
                ScrollView {
                    serverList
                }
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
            try? context.save()
            
            state.editServerSheetServer = nil
            state.editServerSheetMode = .adding
            
            state.updateServerMetadatas()
        } content: {
            EditServerView(server: $state.editServerSheetServer)
        }
        .alert("Delete Server", isPresented: $isShowDeleteServerAlert) {
            Button("Delete", role: .destructive) {
                context.delete(serverToDelete!)
                serverToDelete = nil
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You are about to delete this server. Are you sure?")
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
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(filteredServers) { server in
                ServerCardView(server: server)
                    .onTapGesture {
                        state.pathServers.append(server)
                    }
                    .contextMenu {
                        ControlGroup {
                            Button {
                                state.editServerSheetMode = .editing
                                state.editServerSheetServer = server
                                state.isShowEditServerSheet = true
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            let base64EncodedURL = server.url.data(using: .utf8)!.base64EncodedString(options: .lineLength64Characters)
                            let base64EncodedKey = server.key.data(using: .utf8)!.base64EncodedString(options: .lineLength64Characters)
                            ShareLink(item: "np://master?url=\(base64EncodedURL)&key=\(base64EncodedKey)") {
                                Label("Share", systemImage: "square.and.arrow.up")
                            }
                        }
                        Divider()
                        Button(role: .destructive) {
                            serverToDelete = server
                            isShowDeleteServerAlert = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
            .animation(.default, value: filteredServers)
        }
        .padding(.horizontal, 15)
    }
}
