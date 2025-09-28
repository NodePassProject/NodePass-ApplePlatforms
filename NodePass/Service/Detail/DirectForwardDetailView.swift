//
//  DirectForwardDetailView.swift
//  NodePass
//
//  Created by Junhui Lou on 7/12/25.
//

import SwiftUI
import SwiftData
import Drops

struct DirectForwardDetailView: View {
    @Environment(NPState.self) var state
    
    let service: Service
    var implementation: Implementation {
        service.implementations!.first(where: { $0.position == 0 })!
    }
    var server: Server? {
        servers.first(where: { $0.id == implementation.serverID })
    }
    var addressesAndPorts: (tunnel: (address: String, port: String), destination: (address: String, port: String)) {
        implementation.parseAddressesAndPorts()
    }
    
    @Query private var servers: [Server]
    
    @State private var isShowEditRelayPortAlert: Bool = false
    @State private var newRelayPort: String = ""
    
    @State private var isShowEditDestinationAddressAlert: Bool = false
    @State private var newDestinationAddress: String = ""
    
    @State private var isShowEditDestinationPortAlert: Bool = false
    @State private var newDestinationPort: String = ""
    
    @State private var isShowErrorAlert: Bool = false
    @State private var errorMessage: String = ""
    
    @State private var isSensoryFeedbackTriggered: Bool = false
    
    var body: some View {
        if service.type == .directForward {
            Form {
                if let server {
                    let connectionString = "\(server.getHost()):\(addressesAndPorts.tunnel.port)"
                    Section("You Should Connect To") {
                        Text(connectionString)
                    }
                    .copiable(connectionString)
                }
                
                Section("Relay Server") {
                    HStack {
                        if let server {
                            LabeledContent("Server") {
                                Text(server.name!)
                            }
                            Button {
                                state.tab = .servers
                                state.pathServers.append(server)
                            } label: {
                                Image(systemName: "arrow.right")
                            }
                        }
                        else {
                            LabeledContent("Server") {
                                Text("Not on this device")
                            }
                        }
                    }
                    HStack {
                        LabeledContent("Listen Port") {
                            Text(addressesAndPorts.tunnel.port)
                        }
                        if server != nil {
                            Button {
                                isShowEditRelayPortAlert = true
                            } label: {
                                Image(systemName: "pencil")
                            }
                        }
                    }
                    .copiable(addressesAndPorts.tunnel.port)
                    LabeledContent("Command URL") {
                        Text(implementation.command!)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                    }
                    .copiable(implementation.command!)
                }
                
                Section("Destination Server") {
                    HStack {
                        LabeledContent("Address") {
                            Text(addressesAndPorts.destination.address)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                        }
                        if server != nil {
                            Button {
                                isShowEditDestinationAddressAlert = true
                            } label: {
                                Image(systemName: "pencil")
                            }
                        }
                    }
                    .copiable(addressesAndPorts.destination.address)
                    HStack {
                        LabeledContent("Port") {
                            Text(addressesAndPorts.destination.port)
                        }
                        if server != nil {
                            Button {
                                isShowEditDestinationPortAlert = true
                            } label: {
                                Image(systemName: "pencil")
                            }
                        }
                    }
                    .copiable(addressesAndPorts.destination.port)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(service.name!)
            .alert("Edit Listen Port", isPresented: $isShowEditRelayPortAlert) {
                TextField("Port", text: $newRelayPort)
                Button("OK") {
                    updateImplementation(newRelayPort: newRelayPort)
                    newRelayPort = ""
                }
                Button("Cancel", role: .cancel) {
                    newRelayPort = ""
                }
            } message: {
                Text("Enter a new port.")
            }
            .alert("Edit Address", isPresented: $isShowEditDestinationAddressAlert) {
                TextField("Address", text: $newDestinationAddress)
                Button("OK") {
                    updateImplementation(newDestinationAddress: newDestinationAddress)
                    newDestinationAddress = ""
                }
                Button("Cancel", role: .cancel) {
                    newDestinationAddress = ""
                }
            } message: {
                Text("Enter a new address.")
            }
            .alert("Edit Port", isPresented: $isShowEditDestinationPortAlert) {
                TextField("Port", text: $newDestinationPort)
                Button("OK") {
                    updateImplementation(newDestinationPort: newDestinationPort)
                    newDestinationPort = ""
                }
                Button("Cancel", role: .cancel) {
                    newDestinationPort = ""
                }
            } message: {
                Text("Enter a new port.")
            }
            .alert("Error", isPresented: $isShowErrorAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .sensoryFeedback(.success, trigger: isSensoryFeedbackTriggered)
        }
        else {
            Image(systemName: "exclamationmark.circle")
                .foregroundStyle(.red)
        }
    }
    
    private func updateImplementation(newRelayPort: String) {
        Task {
            let instanceService = InstanceService()
            do {
                let implementation = implementation
                let server = servers.first(where: { $0.id == implementation.serverID })!
                let command = implementation.dryModifyTunnelPort(port: newRelayPort)
                let updatedInstance = try await instanceService.updateInstance(baseURLString: server.url!, apiKey: server.key!, id: implementation.instanceID!, url: command)
                
                implementation.command = command
                implementation.fullCommand = updatedInstance.config ?? command
            }
            catch {
                errorMessage = "Error Updating Instances: \(error.localizedDescription)"
                isShowErrorAlert = true
            }
        }
    }
    
    private func updateImplementation(newDestinationAddress: String) {
        Task {
            let instanceService = InstanceService()
            do {
                let implementation = implementation
                let server = servers.first(where: { $0.id == implementation.serverID })!
                let command = implementation.dryModifyDestinationAddress(address: newDestinationAddress)
                let updatedInstance = try await instanceService.updateInstance(baseURLString: server.url!, apiKey: server.key!, id: implementation.instanceID!, url: command)
                
                implementation.command = command
                implementation.fullCommand = updatedInstance.config ?? command
            }
            catch {
                errorMessage = "Error Updating Instances: \(error.localizedDescription)"
                isShowErrorAlert = true
            }
        }
    }
    
    private func updateImplementation(newDestinationPort: String) {
        Task {
            let instanceService = InstanceService()
            do {
                let implementation = implementation
                let server = servers.first(where: { $0.id == implementation.serverID })!
                let command = implementation.dryModifyDestinationPort(port: newDestinationPort)
                let updatedInstance = try await instanceService.updateInstance(baseURLString: server.url!, apiKey: server.key!, id: implementation.instanceID!, url: command)
                
                implementation.command = command
                implementation.fullCommand = updatedInstance.config ?? command
                
#if os(iOS)
                let drop = Drop(title: String(localized: "Success"), subtitle: String(localized: "Changes are now effective"), icon: UIImage(systemName: "checkmark.circle"))
                Drops.show(drop)
#endif
                isSensoryFeedbackTriggered.toggle()
            }
            catch {
                errorMessage = "Error Updating Instances: \(error.localizedDescription)"
                isShowErrorAlert = true
            }
        }
    }
}
