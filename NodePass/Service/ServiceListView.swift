//
//  ServiceListView.swift
//  NodePass
//
//  Created by Junhui Lou on 6/30/25.
//

import SwiftUI
import SwiftData

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

struct ServiceListView: View {
    @Environment(NPState.self) var state
    @Environment(\.colorScheme) private var scheme
    @Environment(\.modelContext) private var context
    @Query private var services: [Service]
    @Query private var servers: [Server]
    
    @State private var sortIndicator: SortIndicator = SortIndicator(rawValue: NPCore.userDefaults.string(forKey: NPCore.Strings.NPServiceSortIndicator) ?? "date")! {
        didSet {
            NPCore.userDefaults.set(sortIndicator.rawValue, forKey: NPCore.Strings.NPServiceSortIndicator)
        }
    }
    @State private var sortOrder: SortOrder = SortOrder(rawValue: NPCore.userDefaults.string(forKey: NPCore.Strings.NPServiceSortOrder) ?? "ascending")! {
        didSet {
            NPCore.userDefaults.set(sortOrder.rawValue, forKey: NPCore.Strings.NPServiceSortOrder)
        }
    }
    
    private var sortedServices: [Service] {
        services
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
    private var filteredServices: [Service] {
        if searchText == "" {
            return sortedServices
        }
        else {
            return sortedServices.filter { $0.name!.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    @State private var isShowAddNATPassthroughSheet: Bool = false
    @State private var isShowAddDirectForwardSheet: Bool = false
    @State private var isShowAddTunnelForwardSheet: Bool = false
    
    @State private var isShowRenameServiceAlert: Bool = false
    @State private var serviceToRename: Service?
    @State private var newNameOfService: String = ""
    
    @State private var isShowDeleteServiceAlert: Bool = false
    @State private var serviceToDelete: Service?
    
    @State private var isShowErrorAlert: Bool = false
    @State private var errorMessage: String = ""
    
    private let columns: [GridItem] = [GridItem(.adaptive(minimum: 320, maximum: 450))]
    
    var body: some View {
        ZStack {
            switch(scheme) {
            case .light:
                MeshGradient(width: 3, height: 3, points: [
                    .init(0, 0), .init(0.5, 0), .init(1, 0),
                    .init(0, 0.5), .init(0.5, 0.5), .init(1, 0.5),
                    .init(0, 1), .init(0.5, 1), .init(1, 1)
                ], colors: [
                    .red, .purple, .indigo,
                    .orange, .white, .blue,
                    .yellow, .green, .mint
                ])
                .ignoresSafeArea()
            default:
                MeshGradient(width: 3, height: 3, points: [
                    .init(0, 0), .init(0.5, 0), .init(1, 0),
                    .init(0, 0.5), .init(0.5, 0.5), .init(1, 0.5),
                    .init(0, 1), .init(0.5, 1), .init(1, 1)
                ], colors: [
                    .init(red: 0.2, green: 0, blue: 0.3),
                    .init(red: 0.1, green: 0, blue: 0.2),
                    .init(red: 0, green: 0, blue: 0.15),
                    
                    .init(red: 0.3, green: 0.1, blue: 0),
                    .init(red: 0.05, green: 0.05, blue: 0.1),
                    .init(red: 0, green: 0.1, blue: 0.2),
                    
                    .init(red: 0.3, green: 0.2, blue: 0),
                    .init(red: 0, green: 0.15, blue: 0.1),
                    .init(red: 0, green: 0.2, blue: 0.15)
                ])
                .ignoresSafeArea()
            }
            
#if os(macOS)
            ScrollView {
                servicesList
            }
#else
            if services.isEmpty {
                ContentUnavailableView("No Service", systemImage: "square.stack.3d.up.fill", description: Text("To add a service, tap the add service icon in the toolbar.").font(.caption))
            }
            else {
                ScrollView {
                    servicesList
                }
            }
#endif
        }
        .navigationTitle("Services")
        .navigationDestination(for: Service.self) { service in
            switch(service.type) {
            case .natPassthrough:
                NATPassthroughDetailView(service: service)
            case .directForward:
                DirectForwardDetailView(service: service)
            case .tunnelForward:
                TunnelForwardDetailView(service: service)
            case .none:
                Image(systemName: "exclamationmark.circle")
                    .foregroundStyle(.red)
            }
        }
        .searchable(text: $searchText, placement: .toolbar)
        .toolbar {
            ToolbarItem {
                addServiceMenu
            }
            if #available(iOS 26.0, macOS 26.0, *) {
                ToolbarSpacer(.fixed)
            }
            ToolbarItem {
                moreMenu
            }
        }
        .sheet(isPresented: $isShowAddNATPassthroughSheet) {
            AddNATPassthroughServiceView()
        }
        .sheet(isPresented: $isShowAddDirectForwardSheet) {
            AddDirectForwardServiceView()
        }
        .sheet(isPresented: $isShowAddTunnelForwardSheet) {
            AddTunnelForwardServiceView()
        }
        .alert("Rename Service", isPresented: $isShowRenameServiceAlert) {
            TextField("Name", text: $newNameOfService)
            Button("OK") {
                serviceToRename!.name = newNameOfService
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enter a new name for the service.")
        }
        .alert("Delete Service", isPresented: $isShowDeleteServiceAlert) {
            Button("Delete", role: .destructive) {
                deleteService(service: serviceToDelete!)
                serviceToDelete = nil
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You are about to delete this service. This action is irreversible. Are you sure?")
        }
        .alert("Error", isPresented: $isShowErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }
    
    private var addServiceMenu: some View {
        Menu("Add Service", systemImage: "plus") {
            Button {
                isShowAddNATPassthroughSheet = true
            } label: {
                Label("NAT Passthrough", systemImage: "firewall")
            }
            
            Button {
                isShowAddDirectForwardSheet = true
            } label: {
                Label("Direct Forward", systemImage: "arrow.right.circle")
            }
            
            Button {
                isShowAddTunnelForwardSheet = true
            } label: {
                Label("Tunnel Forward", systemImage: "arrow.left.arrow.right.circle")
            }
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
    
    private var servicesList: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(filteredServices) { service in
                ServiceCardView(service: service)
                    .onTapGesture {
                        state.pathServices.append(service)
                    }
                    .contextMenu {
                        Button {
                            serviceToRename = service
                            newNameOfService = service.name!
                            isShowRenameServiceAlert = true
                        } label: {
                            Label("Rename", systemImage: "pencil")
                        }
                        
                        Button(role: .destructive) {
                            serviceToDelete = service
                            isShowDeleteServiceAlert = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
        .padding(.horizontal, 15)
    }
    
    private func deleteService(service: Service) {
        func showGeneralizedErrorMessage(error: Error, instanceID: String) {
            errorMessage = "Error Deleting Instance \(instanceID):\(error.localizedDescription)"
            isShowErrorAlert = true
        }
        
        func deleteInstance(server: Server, instanceID: String) async -> Result<Void, Error> {
            let instanceService = InstanceService()
            do {
                try await instanceService.deleteInstance(baseURLString: server.url!, apiKey: server.key!, id: instanceID)
            }
            catch let error as NetworkError {
                switch error {
                case .serverError(let statusCode, _) where statusCode == 404:
#if DEBUG
                    print("Error Deleting Instance \(instanceID): Instance not found.")
#endif
                    return .success(())
                default:
                    return .failure(error)
                }
            }
            catch {
                return .failure(error)
            }
            return .success(())
        }
        
        Task {
            switch(service.type) {
            case .natPassthrough, .tunnelForward:
                let serverID = service.implementations![0].serverID!
                let serverInstanceID = service.implementations![0].instanceID!
                let clientID = service.implementations![1].serverID!
                let clientInstanceID = service.implementations![1].instanceID!
                guard let server = servers.first(where: { $0.id == serverID }) else {
                    errorMessage = "Error Deleting Instance \(serverInstanceID): Server not found. Service has been deleted but you will have to delete related instances mannually."
                    isShowErrorAlert = true
                    context.delete(service)
                    return
                }
                guard let client = servers.first(where: { $0.id == clientID }) else {
                    errorMessage = "Error Deleting Instance \(clientInstanceID): Server not found. Service has been deleted but you will have to delete related instances mannually."
                    isShowErrorAlert = true
                    context.delete(service)
                    return
                }
                let deleteServerInstanceResult = await deleteInstance(server: server, instanceID: serverInstanceID)
                let deleteClientInstanceResult = await deleteInstance(server: client, instanceID: clientInstanceID)
                switch(deleteServerInstanceResult) {
                case .success:
                    switch(deleteClientInstanceResult) {
                    case .success:
                        context.delete(service)
                    case .failure(let error):
                        showGeneralizedErrorMessage(error: error, instanceID: serverInstanceID)
                    }
                case .failure(let error):
                    showGeneralizedErrorMessage(error: error, instanceID: serverInstanceID)
                }
            case .directForward:
                let clientID = service.implementations![0].serverID!
                let clientInstanceID = service.implementations![0].instanceID!
                guard let client = servers.first(where: { $0.id == clientID }) else {
                    errorMessage = "Error Deleting Instance \(clientInstanceID): Server not found. Service has been deleted but you will have to delete related instances mannually."
                    isShowErrorAlert = true
                    context.delete(service)
                    return
                }
                let deleteClientInstanceResult = await deleteInstance(server: client, instanceID: clientInstanceID)
                switch(deleteClientInstanceResult) {
                case .success:
                    context.delete(service)
                case .failure(let error):
                    showGeneralizedErrorMessage(error: error, instanceID: clientInstanceID)
                }
            case .none:
                return
            }
        }
    }
}
