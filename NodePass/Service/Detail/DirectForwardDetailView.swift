//
//  DirectForwardDetailView.swift
//  NodePass
//
//  Created by Junhui Lou on 7/12/25.
//

import SwiftUI
import SwiftData

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
    
    @State private var isShowEditPortAlert: Bool = false
    @State private var newPort: String = ""
    
    @State private var isShowErrorAlert: Bool = false
    @State private var errorMessage: String = ""
    
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
                                isShowEditPortAlert = true
                            } label: {
                                Image(systemName: "pencil")
                            }
                        }
                    }
                    LabeledContent("Command URL") {
                        Text(implementation.command!)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                    }
                    .copiable(implementation.command!)
                }
                
                Section("Destination Server") {
                    LabeledContent("Address") {
                        Text(addressesAndPorts.destination.address)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                    }
                    .copiable(addressesAndPorts.destination.address)
                    LabeledContent("Port") {
                        Text(addressesAndPorts.destination.port)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(service.name!)
            .alert("Edit Listen Port", isPresented: $isShowEditPortAlert) {
                TextField("Port", text: $newPort)
                Button("OK") {
                    updateImplementation(newPort: newPort)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Enter a new port.")
            }
            .alert("Error", isPresented: $isShowErrorAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
        else {
            Image(systemName: "exclamationmark.circle")
                .foregroundStyle(.red)
        }
    }
    
    private func updateImplementation(newPort: String) {
        Task {
            let instanceService = InstanceService()
            do {
                let server = servers.first(where: { $0.id == implementation.serverID })!
                let command = implementation.dryModifyTunnelPort(port: newPort)
                try await instanceService.updateInstance(baseURLString: server.url!, apiKey: server.key!, id: implementation.instanceID!, url: command)
                implementation.command = command
            }
            catch {
                errorMessage = "Error Updating Instances: \(error.localizedDescription)"
                isShowErrorAlert = true
            }
        }
    }
}
