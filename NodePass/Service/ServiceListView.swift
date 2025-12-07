//
//  ServiceListView.swift
//  NodePass
//
//  Created by Junhui Lou on 6/30/25.
//

import SwiftUI
import SwiftData
import Drops

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
    @Environment(\.modelContext) private var context
    @Query private var services: [Service]
    @Query private var servers: [Server]
    
    private let columns: [GridItem] = [GridItem(.adaptive(minimum: 320, maximum: 450))]
    
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
                    return sortOrder == .ascending ? $0.name < $1.name : $0.name > $1.name
                case .date:
                    return sortOrder == .ascending ? $0.timestamp < $1.timestamp : $0.timestamp > $1.timestamp
                }
            }
    }
    
    @State private var searchText: String = ""
    private var filteredServices: [Service] {
        if searchText == "" {
            return sortedServices
        }
        else {
            return sortedServices
                .filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    @State private var isShowAddNATPassthroughSheet: Bool = false
    @State private var isShowAddDirectForwardSheet: Bool = false
    @State private var isShowAddTunnelForwardSheet: Bool = false
    
    @State private var isShowSyncProgressView: Bool = false
    @State private var syncProgress: (Int, Int) = (0, 0)
    
    @State private var isShowRenameServiceAlert: Bool = false
    @State private var serviceToRename: Service?
    @State private var newNameOfService: String = ""
    
    @State private var isShowDeleteServiceAlert: Bool = false
    @State private var isShowForceDeleteServiceAlert: Bool = false
    @State private var serviceToDelete: Service?
    
    @State private var isShowSyncErrorSheet: Bool = false
    @State private var syncErrorStore: [String: String] = .init()
    
    @State private var isShowErrorAlert: Bool = false
    @State private var errorMessage: String = ""
    
    @State private var isSensoryFeedbackTriggered: Bool = false
    
    var body: some View {
        ZStack {
            BackgroundColorfulView.shared
            
#if os(macOS)
            scrollView
#else
            if services.isEmpty {
                if isShowSyncProgressView {
                    progressView
                }
                else {
                    ContentUnavailableView("No Service", systemImage: "square.stack.3d.up.fill", description: Text("To add a service, tap the add service icon in the toolbar.").font(.caption))
                }
            }
            else {
                scrollView
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
        .alert("Force Delete Service", isPresented: $isShowForceDeleteServiceAlert) {
            Button("Delete", role: .destructive) {
                deleteService(service: serviceToDelete!, isForce: true)
                serviceToDelete = nil
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You are about to force delete this service. This action is irreversible and any error will be ignored. Are you sure?")
        }
        .alert("Error", isPresented: $isShowErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $isShowSyncErrorSheet) {
            SyncErrorReportView(syncErrorStore: $syncErrorStore)
        }
        .sensoryFeedback(.success, trigger: isSensoryFeedbackTriggered)
        .onAppear {
            removeDuplicates()
        }
    }
    
    private var addServiceMenu: some View {
        Menu("Add Service", systemImage: "plus") {
            Button {
                isShowAddDirectForwardSheet = true
            } label: {
                Label("Direct Forward", systemImage: "arrow.right.circle")
            }
            
            Button {
                isShowAddNATPassthroughSheet = true
            } label: {
                Label("NAT Passthrough", systemImage: "firewall")
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
            Button {
                sync()
            } label: {
                Label("Sync", systemImage: "arrow.trianglehead.2.clockwise.rotate.90")
            }
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
    
    private var scrollView: some View {
        ScrollView {
            VStack {
                if isShowSyncProgressView {
                    progressView
                }
                servicesList
            }
            .padding(.vertical)
        }
    }
    
    private var progressView: some View {
        Group {
            let progressPercentage = Double(syncProgress.0) / Double(syncProgress.1)
            let isSyncCompleted = progressPercentage == 1
            
            VStack {
                if isSyncCompleted {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Sync completed")
                    }
                } else {
                    ProgressView("Syncing", value: progressPercentage)
                        .animation(.default, value: progressPercentage)
                }
            }
            .frame(height: 20)
            .padding()
            .animation(.easeInOut, value: isSyncCompleted)
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
                            newNameOfService = service.name
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
                        
                        Button(role: .destructive) {
                            serviceToDelete = service
                            isShowForceDeleteServiceAlert = true
                        } label: {
                            Label("Force Delete", systemImage: "trash.slash")
                        }
                    }
            }
            .animation(.default, value: filteredServices)
        }
        .padding(.horizontal, 15)
    }
    
    private func removeDuplicates() {
        var seenIDs = Set<UUID>()
        var duplicates: [Service] = []
        
        for sercive in services {
            if seenIDs.contains(sercive.id) {
                duplicates.append(sercive)
            } else {
                seenIDs.insert(sercive.id)
            }
        }
        
        for duplicate in duplicates {
            context.delete(duplicate)
        }
        
        try? context.save()
    }
    
    private func deleteService(service: Service, isForce: Bool = false) {
        func showGeneralizedErrorMessage(error: Error, instanceID: String) {
            errorMessage = String(localized: "Error Deleting Instance \(instanceID):\(error.localizedDescription)")
            isShowErrorAlert = true
        }
        
        func deleteInstance(server: Server, instanceID: String) async -> Result<Void, Error> {
            let instanceService = InstanceService()
            do {
                try await instanceService.deleteInstance(baseURLString: server.url, apiKey: server.key, id: instanceID)
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
                let serverID = service.implementations![0].serverID
                let serverInstanceID = service.implementations![0].instanceID
                let clientID = service.implementations![1].serverID
                let clientInstanceID = service.implementations![1].instanceID
                guard let server = servers.first(where: { $0.id == serverID }) else {
                    if isForce {
                        context.delete(service)
                    }
                    else {
                        errorMessage = String(localized: "Error Deleting Instance \(serverInstanceID): Server not found.")
                        isShowErrorAlert = true
                    }
                    return
                }
                guard let client = servers.first(where: { $0.id == clientID }) else {
                    if isForce {
                        context.delete(service)
                        try? context.save()
                    }
                    else {
                        errorMessage = String(localized: "Error Deleting Instance \(clientInstanceID): Server not found.")
                        isShowErrorAlert = true
                    }
                    return
                }
                let deleteServerInstanceResult = await deleteInstance(server: server, instanceID: serverInstanceID)
                let deleteClientInstanceResult = await deleteInstance(server: client, instanceID: clientInstanceID)
                switch(deleteServerInstanceResult) {
                case .success:
                    switch(deleteClientInstanceResult) {
                    case .success:
                        context.delete(service)
                        try? context.save()
                    case .failure(let error):
                        if isForce {
                            context.delete(service)
                            try? context.save()
                        }
                        else {
                            showGeneralizedErrorMessage(error: error, instanceID: serverInstanceID)
                        }
                    }
                case .failure(let error):
                    if isForce {
                        context.delete(service)
                        try? context.save()
                    }
                    else {
                        showGeneralizedErrorMessage(error: error, instanceID: serverInstanceID)
                    }
                }
            case .directForward:
                let clientID = service.implementations![0].serverID
                let clientInstanceID = service.implementations![0].instanceID
                guard let client = servers.first(where: { $0.id == clientID }) else {
                    if isForce {
                        context.delete(service)
                        try? context.save()
                    }
                    else {
                        errorMessage = String(localized: "Error Deleting Instance \(clientInstanceID): Server not found.")
                        isShowErrorAlert = true
                    }
                    return
                }
                let deleteClientInstanceResult = await deleteInstance(server: client, instanceID: clientInstanceID)
                switch(deleteClientInstanceResult) {
                case .success:
                    context.delete(service)
                    try? context.save()
                case .failure(let error):
                    if isForce {
                        context.delete(service)
                        try? context.save()
                    }
                    else {
                        showGeneralizedErrorMessage(error: error, instanceID: clientInstanceID)
                    }
                }
            }
        }
    }
    
    private func sync() {
        Task {
            let instanceService = InstanceService()
            var store: [String: [Instance]] = .init() // Server.id: [Instance]
            var errorStore: [String: String] = .init() // (Server.name || Server.id): Error.localizedDescription
            var examinedServiceIds: [String] = .init()
            syncProgress = (0, servers.count)
            withAnimation {
                isShowSyncProgressView = true
            }
            try await withThrowingTaskGroup(of: (server: Server, result: Result<[Instance], Error>).self) { group in
                for server in servers {
                    group.addTask {
                        do {
                            let instances = try await instanceService.listInstances(
                                baseURLString: server.url,
                                apiKey: server.key
                            )
                            return (server, .success(instances))
                        } catch {
                            return (server, .failure(error))
                        }
                    }
                }
                
                for try await (server, result) in group {
                    switch result {
                    case .success(let instances):
                        store[server.id] = instances
                    case .failure(let error):
                        errorStore[server.id] = error.localizedDescription
                    }
                    syncProgress = (syncProgress.0 + 1, syncProgress.1)
                }
            }
            for serverId in store.keys {
                for instance in store[serverId]! {
                    if let serviceId = instance.metadata?.peer.serviceId, serviceId != "", !examinedServiceIds.contains(serviceId) {
                        let serverId0 = serverId
                        let instance0 = instance
                        if ["0", "5"].contains(instance0.metadata!.peer.serviceType) && !services.map({ $0.id.uuidString }).contains(serviceId) {
                            // Direct Forward
                            let clientId = serverId0
                            let clientInstance = instance0
                            let service = Service(
                                id: UUID(uuidString: serviceId) ?? UUID(),
                                name: instance.metadata?.peer.alias ?? String(localized: "Untitled"),
                                type: .directForward,
                                implementations: [
                                    Implementation(
                                        name: clientInstance.metadata!.peer.alias,
                                        type: .directForwardClient,
                                        position: 0,
                                        serverID: clientId,
                                        instanceID: clientInstance.id,
                                        command: clientInstance.url,
                                        fullCommand: clientInstance.config ?? clientInstance.url
                                    )
                                ]
                            )
                            context.insert(service)
                            try? context.save()
                            
                            examinedServiceIds.append(serverId)
                            continue
                        }
                        for serverId in store.keys {
                            for instance in store[serverId]! {
                                if instance.metadata?.peer.serviceId == serviceId {
                                    if !services.map({ $0.id.uuidString }).contains(serviceId) {
                                        let serverId1 = serverId
                                        let instance1 = instance
                                        
                                        switch(instance.metadata!.peer.serviceType) {
                                        case "1", "3", "6":
                                            // NAT Passthrough
                                            let schemeOfInstance0 = NPCore.parseScheme(urlString: instance0.url)
                                            let schemeOfInstance1 = NPCore.parseScheme(urlString: instance1.url)
                                            let serverId: String
                                            let clientId: String
                                            let serverInstance: Instance
                                            let clientInstance: Instance
                                            if schemeOfInstance0 == .server && schemeOfInstance1 == .client {
                                                serverId = serverId0
                                                serverInstance = instance0
                                                clientId = serverId1
                                                clientInstance = instance1
                                            }
                                            else if schemeOfInstance1 == .server && schemeOfInstance0 == .client {
                                                serverId = serverId1
                                                serverInstance = instance1
                                                clientId = serverId0
                                                clientInstance = instance0
                                            }
                                            else {
                                                continue
                                            }
                                            let service = Service(
                                                id: UUID(uuidString: serviceId) ?? UUID(),
                                                name: instance.metadata?.peer.alias ?? String(localized: "Untitled"),
                                                type: .natPassthrough,
                                                implementations: [
                                                    Implementation(
                                                        name: serverInstance.metadata!.peer.alias,
                                                        type: .natPassthroughServer,
                                                        position: 0,
                                                        serverID: serverId,
                                                        instanceID: serverInstance.id,
                                                        command: serverInstance.url,
                                                        fullCommand: serverInstance.config ?? serverInstance.url
                                                    ),
                                                    Implementation(
                                                        name: clientInstance.metadata!.peer.alias,
                                                        type: .natPassthroughClient,
                                                        position: 1,
                                                        serverID: clientId,
                                                        instanceID: clientInstance.id,
                                                        command: clientInstance.url,
                                                        fullCommand: clientInstance.config ?? clientInstance.url
                                                    )
                                                ]
                                            )
                                            context.insert(service)
                                            try? context.save()
                                            
                                            examinedServiceIds.append(serverId)
                                            continue
                                        case "2", "4", "7":
                                            // Tunnel Forward
                                            let schemeOfInstance0 = NPCore.parseScheme(urlString: instance0.url)
                                            let modeOfInstance0 = NPCore.parseQueryParameters(urlString: instance0.url)["mode"]
                                            let schemeOfInstance1 = NPCore.parseScheme(urlString: instance1.url)
                                            let modeOfInstance1 = NPCore.parseQueryParameters(urlString: instance1.url)["mode"]
                                            guard let modeOfInstance0, let modeOfInstance1 else {
                                                continue
                                            }
                                            let relayServerId: String
                                            let destinationServerId: String
                                            let relayServerInstance: Instance
                                            let destinationServerInstance: Instance
                                            if (schemeOfInstance0 == .server && modeOfInstance0 == "1") || (schemeOfInstance1 == .server && modeOfInstance1 == "2") {
                                                relayServerId = serverId0
                                                relayServerInstance = instance0
                                                destinationServerId = serverId1
                                                destinationServerInstance = instance1
                                            }
                                            else if (schemeOfInstance1 == .server && modeOfInstance1 == "1") || (schemeOfInstance0 == .server && modeOfInstance0 == "2") {
                                                relayServerId = serverId1
                                                relayServerInstance = instance1
                                                destinationServerId = serverId0
                                                destinationServerInstance = instance0
                                            }
                                            else {
                                                continue
                                            }
                                            let service = Service(
                                                id: UUID(uuidString: serviceId) ?? UUID(),
                                                name: instance.metadata?.peer.alias ?? String(localized: "Untitled"),
                                                type: .tunnelForward,
                                                implementations: [
                                                    Implementation(
                                                        name: relayServerInstance.metadata!.peer.alias,
                                                        type: .tunnelForwardRelay,
                                                        position: 0,
                                                        serverID: relayServerId,
                                                        instanceID: relayServerInstance.id,
                                                        command: relayServerInstance.url,
                                                        fullCommand: relayServerInstance.config ?? relayServerInstance.url
                                                    ),
                                                    Implementation(
                                                        name: destinationServerInstance.metadata!.peer.alias,
                                                        type: .tunnelForwardDestination,
                                                        position: 1,
                                                        serverID: destinationServerId,
                                                        instanceID: destinationServerInstance.id,
                                                        command: destinationServerInstance.url,
                                                        fullCommand: destinationServerInstance.config ?? destinationServerInstance.url
                                                    )
                                                ]
                                            )
                                            context.insert(service)
                                            try? context.save()
                                            
                                            examinedServiceIds.append(serverId)
                                            continue
                                        default:
                                            continue
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            if errorStore.count == 0 {
                isSensoryFeedbackTriggered.toggle()
            }
            else {
                syncErrorStore = errorStore
                isShowSyncErrorSheet = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation {
                    isShowSyncProgressView = false
                }
            }
        }
    }
}
