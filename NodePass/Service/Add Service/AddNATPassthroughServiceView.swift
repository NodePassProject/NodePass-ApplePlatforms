//
//  AddNATPassthroughServiceView.swift
//  NodePass
//
//  Created by Junhui Lou on 7/2/25.
//

import SwiftUI
import SwiftData

struct AddNATPassthroughServiceView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \Server.timestamp) private var servers: [Server]
    
    @State private var name: String = ""
    @State private var server: Server?
    @State private var serverConnectPort: String = ""
    @State private var serverTunnelPort: String = ""
    @State private var client: Server?
    @State private var clientServicePort: String = ""
    @State private var isTLS: Bool = false
    
    @State private var isShowErrorAlert: Bool = false
    @State private var errorMessage: String = ""
    @State private var isShowAddServerSheet: Bool = false
    @State private var isAddingServer: Bool = false
    @State private var isAddingClient: Bool = false
    @State private var newServer: Server?
    
    @State private var isSensoryFeedbackTriggered: Bool = false
    
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
                    LabeledTextField("Listen Port", prompt: "10022", text: $serverConnectPort, isNumberOnly: true)
                    LabeledTextField("Tunnel Port", prompt: "10101", text: $serverTunnelPort, isNumberOnly: true)
                } header: {
                    HStack {
                        Text("Remote Server (with Public IP)")
                        Spacer()
                        Button {
                            isAddingServer = true
                            isShowAddServerSheet = true
                        } label: {
                            Text("\(Image(systemName: "plus")) New Server")
                                .font(.caption)
                        }
                    }
                } footer: {
                    VStack(alignment: .leading) {
                        Text("Remote Server: Server with a public IP.")
                        Text("Listen Port: Port you use to connect to the remote server.")
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
                    LabeledTextField("Service Port", prompt: "22", text: $clientServicePort, isNumberOnly: true)
                } header: {
                    HStack {
                        Text("Local Server (Behind NAT)")
                        Spacer()
                        Button {
                            isAddingClient = true
                            isShowAddServerSheet = true
                        } label: {
                            Text("\(Image(systemName: "plus")) New Server")
                                .font(.caption)
                        }
                    }
                } footer: {
                    VStack(alignment: .leading) {
                        Text("Local Server: Server without a public IP.")
                        Text("Service Port: Port on which your service like SSH(22) is running.")
                    }
                }
                
                Section {
                    Toggle("TLS", isOn: $isTLS)
                } footer: {
                    Text("Use TLS encryption for tunnel communication.")
                }
                
                Section("Preview") {
                    let serverConnectPort = Int(serverConnectPort) ?? 10022
                    let serverTunnelPort = Int(serverTunnelPort) ?? 10101
                    let clientServicePort = Int(clientServicePort) ?? 22
                    
                    let serverCommand = "server://:\(serverTunnelPort)/:\(serverConnectPort)?log=warn&tls=\(isTLS ? "1" : "0")"
                    let clientCommand = "client://\(server?.getHost() ?? ""):\(serverTunnelPort)/127.0.0.1:\(clientServicePort)?log=warn"
                    
                    let name = NPCore.noEmptyName(name)
                    let previewService = Service(
                        name: name,
                        type: .natPassthrough,
                        implementations: [
                            Implementation(
                                name: String(localized: "\(name) Remote"),
                                type: .natPassthroughServer,
                                position: 0,
                                serverID: server?.id ?? "",
                                instanceID: "",
                                command: serverCommand,
                                fullCommand: serverCommand
                            ),
                            Implementation(
                                name: String(localized: "\(name) Local"),
                                type: .natPassthroughClient,
                                position: 1,
                                serverID: client?.id ?? "",
                                instanceID: "",
                                command: clientCommand,
                                fullCommand: clientCommand
                            )
                        ]
                    )
                    
                    NATPassthroughCardView(service: previewService, isPreview: true)
                }
                
#if DEBUG
                Section {
                    Button("Sample") {
                        name = "Sample NAT Passthrough"
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
            .navigationTitle("Add NAT Passthrough")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel) {
                        dismiss()
                    } label: {
                        Label("Cancel", systemImage: "xmark")
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    if #available(iOS 26.0, macOS 26.0, *) {
                        Button(role: .confirm) {
                            execute()
                        } label: {
                            Label("Done", systemImage: "checkmark")
                        }
                        .disabled(server == nil || client == nil)
                    }
                    else {
                        Button("Done") {
                            execute()
                        }
                        .disabled(server == nil || client == nil)
                    }
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
            .sensoryFeedback(.success, trigger: isSensoryFeedbackTriggered)
        }
    }
    
    private func execute() {
        let server = server!
        let client = client!
        
        let serverConnectPort = Int(serverConnectPort) ?? 10022
        let serverTunnelPort = Int(serverTunnelPort) ?? 10101
        let clientServicePort = Int(clientServicePort) ?? 22
        
        let serverCommand = "server://:\(serverTunnelPort)/:\(serverConnectPort)\(isTLS ? "?tls=1" : "")"
        let clientCommand = "client://\(server.getHost()):\(serverTunnelPort)/127.0.0.1:\(clientServicePort)"
        
        Task {
            let instanceService = InstanceService()
            do {
                async let createServerInstance: (Instance) = instanceService.createInstance(
                    baseURLString: server.url!,
                    apiKey: server.key!,
                    url: serverCommand
                )
                async let createClientInstance: (Instance) = instanceService.createInstance(
                    baseURLString: client.url!,
                    apiKey: client.key!,
                    url: clientCommand
                )
                
                let (serverInstance, clientInstance) = try await (createServerInstance, createClientInstance)
                
                let serverFullCommand = serverInstance.config ?? serverCommand
                let clientFullCommand = clientInstance.config ?? clientCommand
                
                let name = NPCore.noEmptyName(name)
                let service = Service(
                    name: name,
                    type: .natPassthrough,
                    implementations: [
                        Implementation(
                            name: String(localized: "\(name) Remote"),
                            type: .natPassthroughServer,
                            position: 0,
                            serverID: server.id!,
                            instanceID: serverInstance.id,
                            command: serverCommand,
                            fullCommand: serverFullCommand
                        ),
                        Implementation(
                            name: String(localized: "\(name) Local"),
                            type: .natPassthroughClient,
                            position: 1,
                            serverID: client.id!,
                            instanceID: clientInstance.id,
                            command: clientCommand,
                            fullCommand: clientFullCommand
                        )
                    ]
                )
                context.insert(service)
                try? context.save()
                
                dismiss()
                
                isSensoryFeedbackTriggered.toggle()
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
