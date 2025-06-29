//
//  AddTunnelForwardServiceView.swift
//  NodePass
//
//  Created by Junhui Lou on 7/4/25.
//

import SwiftUI
import SwiftData

struct AddTunnelForwardServiceView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \Server.timestamp) private var servers: [Server]
    
    @State private var name: String = ""
    @State private var server: Server?
    @State private var serverConnectPort: String = ""
    @State private var serverTunnelPort: String = ""
    @State private var client: Server?
    @State private var clientServicePort: String = ""
    
    @State private var isShowErrorAlert: Bool = false
    @State private var errorMessage: String = ""
    @State private var isShowAddServerSheet: Bool = false
    @State private var isAddingServer: Bool = false
    @State private var isAddingClient: Bool = false
    @State private var newServer: Server?
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                }
                
                Section {
                    Picker("Server", selection: $server) {
                        Text("Select")
                            .tag(nil as Server?)
                        ForEach(servers) { server in
                            Text(server.name!)
                                .tag(server)
                        }
                    }
                    if server == nil {
                        Button {
                            isAddingServer = true
                            isShowAddServerSheet = true
                        } label: {
                            Text("New Server")
                        }
                    }
                    LabeledTextField("Listen Port", prompt: "10022", text: $serverConnectPort, isNumberOnly: true)
                    LabeledTextField("Tunnel Port", prompt: "10101", text: $serverTunnelPort, isNumberOnly: true)
                } header: {
                    Text("Relay Server")
                } footer: {
                    VStack(alignment: .leading) {
                        Text("Relay Server: Server you want to use as a relay.")
                        Text("Listen Port: Port you use to connect to the relay server.")
                        Text("Tunnel Port: Any available port.")
                    }
                }
                
                Section {
                    Picker("Server", selection: $client) {
                        Text("Select")
                            .tag(nil as Server?)
                        ForEach(servers) { server in
                            Text(server.name!)
                                .tag(server)
                        }
                    }
                    if client == nil {
                        Button {
                            isAddingClient = true
                            isShowAddServerSheet = true
                        } label: {
                            Text("New Server")
                        }
                    }
                    LabeledTextField("Service Port", prompt: "1080", text: $clientServicePort, isNumberOnly: true)
                } header: {
                    Text("Destination Server")
                } footer: {
                    VStack(alignment: .leading) {
                        Text("Destination Server: Server you want your traffic to relay to.")
                        Text("Service Port: Port on which your service like Socks5(1080) is running.")
                    }
                }
                
                Section("Preview") {
                    let serverConnectPort = Int(serverConnectPort) ?? 10022
                    let serverTunnelPort = Int(serverTunnelPort) ?? 10101
                    let clientServicePort = Int(clientServicePort) ?? 1080
                    
                    let name = NPCore.noEmptyName(name)
                    let previewService = Service(
                        name: name,
                        type: .tunnelForward,
                        implementations: [
                            Implementation(
                                name: String(localized: "\(name) Relay"),
                                type: .tunnelForwardServer,
                                position: 0,
                                serverID: "",
                                instanceID: "",
                                tunnelAddress: "",
                                tunnelPort: serverTunnelPort,
                                destinationAddress: "",
                                destinationPort: serverConnectPort,
                                command: ""
                            ),
                            Implementation(
                                name: String(localized: "\(name) Destination"),
                                type: .tunnelForwardClient,
                                position: 1,
                                serverID: "",
                                instanceID: "",
                                tunnelAddress: "",
                                tunnelPort: serverTunnelPort,
                                destinationAddress: "",
                                destinationPort: clientServicePort,
                                command: ""
                            )
                        ]
                    )
                    
                    TunnelForwardCardView(service: previewService, isPreview: true)
                }
                
#if DEBUG
                Section {
                    Button("Sample") {
                        name = "Sample Tunnel Forward"
                        server = servers.first
                        serverConnectPort = "60001"
                        serverTunnelPort = "60002"
                        client = servers.first
                        clientServicePort = "60003"
                    }
                }
#endif
            }
            .formStyle(.grouped)
            .navigationTitle("Add Tunnel Forward")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Label("Cancel", systemImage: "xmark")
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        execute()
                    } label: {
                        Label("Done", systemImage: "checkmark")
                    }
                    .disabled(server == nil || client == nil)
                }
            }
            .alert("Error", isPresented: $isShowErrorAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .sheet(isPresented: $isShowAddServerSheet) {
                if isAddingServer {
                    server = newServer
                }
                if isAddingClient {
                    client = newServer
                }
            } content: {
                EditServerView(server: $newServer)
            }
        }
    }
    
    private func execute() {
        let serverCommand = "server://:\(serverTunnelPort)/:\(serverConnectPort)?log=warn&tls=0"
        let clientCommand = "client://\(server!.getHost()):\(serverTunnelPort)/127.0.0.1:\(clientServicePort)?log=warn"

        Task {
            do {
                let serverInstanceService = InstanceService()
                let serverInstance = try await serverInstanceService.createInstance(
                    baseURLString: server!.url!,
                    apiKey: server!.key!,
                    url: serverCommand
                )
                
                let clientInstanceService = InstanceService()
                let clientInstance = try await clientInstanceService.createInstance(
                    baseURLString: client!.url!,
                    apiKey: client!.key!,
                    url: clientCommand
                )
                
                let serverConnectPort = Int(serverConnectPort)!
                let serverTunnelPort = Int(serverTunnelPort)!
                let clientServicePort = Int(clientServicePort)!
                
                let name = NPCore.noEmptyName(name)
                let service = Service(
                    name: name,
                    type: .tunnelForward,
                    implementations: [
                        Implementation(
                            name: String(localized: "\(name) Relay"),
                            type: .tunnelForwardServer,
                            position: 0,
                            serverID: server!.id!,
                            instanceID: serverInstance.id,
                            tunnelAddress: "",
                            tunnelPort: serverTunnelPort,
                            destinationAddress: "",
                            destinationPort: serverConnectPort,
                            command: serverCommand
                        ),
                        Implementation(
                            name: String(localized: "\(name) Destination"),
                            type: .tunnelForwardClient,
                            position: 1,
                            serverID: client!.id!,
                            instanceID: clientInstance.id,
                            tunnelAddress: server!.getHost(),
                            tunnelPort: serverTunnelPort,
                            destinationAddress: "127.0.0.1",
                            destinationPort: clientServicePort,
                            command: clientCommand
                        )
                    ]
                )
                context.insert(service)
                
                dismiss()
            } catch {
#if DEBUG
                print("Error Creating Instances: \(error.localizedDescription)")
#endif
                
                errorMessage = error.localizedDescription
                isShowErrorAlert = true
            }
        }
    }
}
