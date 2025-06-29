//
//  ServiceListView.swift
//  NodePass
//
//  Created by Junhui Lou on 6/30/25.
//

import SwiftUI
import SwiftData

struct ServiceListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Service.timestamp) private var services: [Service]
    @Query private var servers: [Server]
    
    @State private var isShowAddNATPassthroughSheet: Bool = false
    @State private var isShowAddDirectForwardSheet: Bool = false
    @State private var isShowAddTunnelForwardSheet: Bool = false
    
    @State private var isShowDeleteServiceAlert: Bool = false
    @State private var serviceToDelete: Service?
    
    @State private var isShowErrorAlert: Bool = false
    @State private var errorMessage: String = ""
    
    private let columns: [GridItem] = [GridItem(.adaptive(minimum: 320, maximum: 450))]
    
    var body: some View {
        ZStack {
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
            
            if services.isEmpty {
                ContentUnavailableView("No Service", systemImage: "square.stack.3d.up.fill", description: Text("To add a service, tap the add service icon in the toolbar.").font(.caption))
            }
            else {
                ScrollView {
                    servicesList
                }
            }
        }
        .navigationTitle("Services")
        .toolbar {
            ToolbarItem {
                addServiceMenu
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
    
    private var servicesList: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(services) { service in
                ServiceCardView(service: service)
                    .contextMenu {
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
