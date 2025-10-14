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
    
    private let columns: [GridItem] = [GridItem(.adaptive(minimum: 320, maximum: 450))]
    
    @State private var isShowDeleteServerAlert: Bool = false
    @State private var serverToDelete: Server?
    
    var body: some View {
        @Bindable var state = state
        ZStack {
            BackgroundColorfulView.shared
            
#if os(macOS)
            ScrollView {
                serverList
            }
#else
            if servers.isEmpty {
                ContentUnavailableView("No Server", systemImage: "square.stack.3d.up.fill", description: Text("To add a server, tap the add server icon in the toolbar.").font(.caption))
            }
            else {
                ScrollView {
                    serverList
                }
            }
#endif
            
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
                serverCardView(server: server)
                    .onTapGesture {
                        state.pathServers.append(server)
                    }
                    .contextMenu {
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
    
    @ViewBuilder
    private func serverCardView(server: Server) -> some View {
        let metadata = state.serverMetadatas[server.id]
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading) {
                HStack(spacing: 10) {
                    Text(server.name)
                    if let uptime = metadata?.uptime {
                        HStack(spacing: 5) {
                            Image(systemName: "power")
                            Text(NPCore.formatTimeInterval(seconds: uptime))
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
#if DEBUG
                Text(verbatim: "https://node.nodepass.eu/api/v1")
                    .font(.caption)
                    .foregroundStyle(.secondary)
#else
                Text(server.url!)
                    .font(.caption)
                    .foregroundStyle(.secondary)
#endif
            }
            
            Spacer()
            
            if let metadata {
                if let cpu = metadata.cpu, let memoryUsed = metadata.memoryUsed, let memoryTotal = metadata.memoryTotal, let swapUsed = metadata.swapUsed, let swapTotal = metadata.swapTotal, let networkReceive = metadata.networkReceive, let networkTransmit = metadata.networkTransmit {
                    HStack(alignment: .top) {
                        Gauge(value: Double(cpu), in: 0...100) {
                            Text("CPU")
                                .font(.system(.caption, design: .rounded))
                                .bold()
                        }
                        .gaugeStyle(SingleMatrixGaugeStyle(color: .blue, size: 50))
                        Spacer()
                        Gauge(value: Double(memoryUsed) / Double(memoryTotal), in: 0...1) {
                            Text("Memory")
                                .font(.system(.caption, design: .rounded))
                                .bold()
                        }
                        .gaugeStyle(SingleMatrixGaugeStyle(color: .blue, size: 50))
                        Spacer()
                        let swapPercentage = swapTotal == 0 ? 0 : Double(swapUsed) / Double(swapTotal)
                        Gauge(value: swapPercentage, in: 0...1) {
                            Text("Swap")
                                .font(.system(.caption, design: .rounded))
                                .bold()
                        }
                        .gaugeStyle(SingleMatrixGaugeStyle(color: .blue, size: 50))
                        Spacer()
                        VStack {
                            let networkReceiveDouble: Double = Double(networkReceive)
                            let networkTransmitDouble: Double = Double(networkTransmit)
                            let networkTotalDouble: Double = networkReceiveDouble + networkTransmitDouble
                            Gauge(value: networkReceiveDouble / networkTotalDouble, in: 0...1) {
                                Text("Network")
                                    .font(.system(.caption, design: .rounded))
                                    .bold()
                            }
                            .gaugeStyle(
                                DoubleMatrixGaugeStyle(
                                    text1: "↑ \(NPCore.formatBytes(networkTransmit, decimals: 0))",
                                    text2: "↓ \(NPCore.formatBytes(networkReceive, decimals: 0))",
                                    color1: .cyan,
                                    color2: .orange,
                                    size: 50
                                )
                            )
                        }
                    }
                }
                else {
                    Text("Matrix Unavailable")
                        .bold()
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
                
                Spacer()
                
                HStack {
                    Text(metadata.os)
                    Text(metadata.architecture)
                    Text(metadata.version)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            else {
                Text("Metadata Unavailable")
                    .bold()
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                Spacer()
            }
        }
        .frame(height: 180)
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .foregroundStyle(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.08), radius: 5, x: 5, y: 5)
                .shadow(color: .black.opacity(0.06), radius: 5, x: -5, y: -5)
        )
    }
}
