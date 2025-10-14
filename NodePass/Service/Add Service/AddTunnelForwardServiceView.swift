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
    @State private var relayServer: Server?
    @State private var relayServerConnectPort: String = ""
    @State private var destinationServer: Server?
    @State private var destinationServerServicePort: String = ""
    @State private var tunnelPort: String = ""
    @State private var isRelayServerAsNPServer: Bool = true
    @State private var isDestinationServerAsNPServer: Bool = false
    @State private var isTLS: Bool = false
    
    @State private var isShowErrorAlert: Bool = false
    @State private var errorMessage: String = ""
    @State private var isShowAddServerSheet: Bool = false
    @State private var isAddingRelayServer: Bool = false
    @State private var isAddingDestinationServer: Bool = false
    @State private var newServer: Server?
    
    @State private var isSensoryFeedbackTriggered: Bool = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                }
                
                Section {
                    Picker("Server", selection: $relayServer) {
                        Text("Select")
                            .tag(nil as Server?)
                        ForEach(servers) { server in
                            Text(server.name)
                                .tag(server)
                        }
                    }
                    LabeledTextField("Listen Port", prompt: "10022", text: $relayServerConnectPort, isNumberOnly: true)
                    Toggle("As NodePass Server", isOn: $isRelayServerAsNPServer)
                        .onChange(of: isRelayServerAsNPServer) { _, newValue in
                            isDestinationServerAsNPServer = !newValue
                        }
                    if isRelayServerAsNPServer {
                        LabeledTextField("Tunnel Port", prompt: "10101", text: $tunnelPort, isNumberOnly: true)
                    }
                } header: {
                    HStack {
                        Text("Relay Server")
                        Spacer()
                        Button {
                            isAddingRelayServer = true
                            isShowAddServerSheet = true
                        } label: {
                            Text("\(Image(systemName: "plus")) New Server")
                                .font(.caption)
                        }
                    }
                } footer: {
                    VStack(alignment: .leading) {
                        Text("Relay Server: Server you want to use as a relay.")
                        Text("Listen Port: Port you use to connect to the relay server.")
                        Text("As NodePass Server: If on, relay server receives tunnel requests from destination server.")
                        if isRelayServerAsNPServer {
                            Text("Tunnel Port: Any available port.")
                        }
                    }
                }
                
                Section {
                    Picker("Server", selection: $destinationServer) {
                        Text("Select")
                            .tag(nil as Server?)
                        ForEach(servers) { server in
                            Text(server.name)
                                .tag(server)
                        }
                    }
                    LabeledTextField("Service Port", prompt: "1080", text: $destinationServerServicePort, isNumberOnly: true)
                    Toggle("As NodePass Server", isOn: $isDestinationServerAsNPServer)
                        .onChange(of: isDestinationServerAsNPServer) { _, newValue in
                            isRelayServerAsNPServer = !newValue
                        }
                    if isDestinationServerAsNPServer {
                        LabeledTextField("Tunnel Port", prompt: "10101", text: $tunnelPort, isNumberOnly: true)
                    }
                } header: {
                    HStack {
                        Text("Destination Server")
                        Spacer()
                        Button {
                            isAddingDestinationServer = true
                            isShowAddServerSheet = true
                        } label: {
                            Text("\(Image(systemName: "plus")) New Server")
                                .font(.caption)
                        }
                    }
                } footer: {
                    VStack(alignment: .leading) {
                        Text("Destination Server: Server you want your traffic to relay to.")
                        Text("Service Port: Port on which your service like Socks5(1080) is running.")
                        Text("As NodePass Server: If on, destination server receives tunnel requests from relay server.")
                        if isDestinationServerAsNPServer {
                            Text("Tunnel Port: Any available port.")
                        }
                    }
                }
                
                Section {
                    Toggle("TLS", isOn: $isTLS)
                } footer: {
                    Text("Use TLS encryption for tunnel communication.")
                }
                
                if #available(iOS 18.0, *) {
                    Section("Preview") {
                        let commands = generateCommands()
                        let relayServerCommand = commands.relayServerCommand
                        let destinationServerCommand = commands.destinationServerCommand
                        
                        let name = NPCore.noEmptyName(name)
                        let previewService = Service(
                            name: name,
                            type: .tunnelForward,
                            implementations: [
                                Implementation(
                                    name: String(localized: "\(name) Relay"),
                                    type: .tunnelForwardRelay,
                                    position: 0,
                                    serverID: relayServer?.id ?? "",
                                    instanceID: "",
                                    command: relayServerCommand,
                                    fullCommand: relayServerCommand
                                ),
                                Implementation(
                                    name: String(localized: "\(name) Destination"),
                                    type: .tunnelForwardDestination,
                                    position: 1,
                                    serverID: destinationServer?.id ?? "",
                                    instanceID: "",
                                    command: destinationServerCommand,
                                    fullCommand: destinationServerCommand
                                )
                            ]
                        )
                        
                        TunnelForwardCardView(service: previewService, isPreview: true)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Add Tunnel Forward")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if #available(iOS 26.0, macOS 26.0, *) {
                        Button(role: .cancel) {
                            dismiss()
                        } label: {
                            Label("Cancel", systemImage: "xmark")
                        }
                    }
                    else {
                        Button("Cancel", role: .cancel) {
                            dismiss()
                        }
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    if #available(iOS 26.0, macOS 26.0, *) {
                        Button(role: .confirm) {
                            dismiss()
                            execute()
                        } label: {
                            Label("Done", systemImage: "checkmark")
                        }
                        .disabled(relayServer == nil || destinationServer == nil)
                    }
                    else {
                        Button("Done") {
                            dismiss()
                            execute()
                        }
                        .disabled(relayServer == nil || destinationServer == nil)
                    }
                }
            }
            .alert("Error", isPresented: $isShowErrorAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .sheet(isPresented: $isShowAddServerSheet) {
                if isAddingRelayServer {
                    relayServer = newServer
                }
                if isAddingDestinationServer {
                    destinationServer = newServer
                }
            } content: {
                EditServerView(server: $newServer)
            }
            .sensoryFeedback(.success, trigger: isSensoryFeedbackTriggered)
        }
    }
    
    private func generateCommands() -> (relayServerCommand: String, destinationServerCommand: String) {
        let relayServerConnectPort = Int(relayServerConnectPort) ?? 10022
        let destinationServerServicePort = Int(destinationServerServicePort) ?? 1080
        let tunnelPort = Int(tunnelPort) ?? 10101
        
        var relayServerCommand: String
        if isRelayServerAsNPServer {
            relayServerCommand = "server://:\(tunnelPort)/:\(relayServerConnectPort)"
        }
        else {
            relayServerCommand = "client://\(destinationServer?.getHost() ?? ""):\(tunnelPort)/:\(relayServerConnectPort)"
        }
        if isRelayServerAsNPServer {
            relayServerCommand += "?mode=1"
            if isTLS {
                relayServerCommand += "&tls=1"
            }
        }
        else {
            relayServerCommand += "?mode=2"
        }
        
        var destinationServerCommand: String
        if isDestinationServerAsNPServer {
            destinationServerCommand = "server://:\(tunnelPort)/127.0.0.1:\(destinationServerServicePort)"
        }
        else {
            destinationServerCommand = "client://\(relayServer?.getHost() ?? ""):\(tunnelPort)/127.0.0.1:\(destinationServerServicePort)"
        }
        if isDestinationServerAsNPServer && isTLS {
            destinationServerCommand += "?mode=2"
            if isTLS {
                destinationServerCommand += "&tls=1"
            }
        }
        else {
            destinationServerCommand += "?mode=2"
        }
        
        return (relayServerCommand, destinationServerCommand)
    }
    
    private func execute() {
        let relayServer = relayServer!
        let destinationServer = destinationServer!
        
        let commands = generateCommands()
        let relayServerCommand = commands.relayServerCommand
        let destinationServerCommand = commands.destinationServerCommand

        Task {
            let instanceService = InstanceService()
            do {
                async let createRelayServerInstance = instanceService.createInstance(
                    baseURLString: relayServer.url,
                    apiKey: relayServer.key,
                    url: relayServerCommand
                )
                async let createDestinationServerInstance = instanceService.createInstance(
                    baseURLString: destinationServer.url,
                    apiKey: destinationServer.key,
                    url: destinationServerCommand
                )
                
                let (relayServerInstance, destinationServerInstance) = try await (createRelayServerInstance, createDestinationServerInstance)
                
                let relayServerFullCommand = relayServerInstance.config ?? relayServerCommand
                let destinationServerFullCommand = destinationServerInstance.config ?? destinationServerCommand
                
                let serviceId = UUID()
                let name = NPCore.noEmptyName(name)
                let service = Service(
                    id: serviceId,
                    name: name,
                    type: .tunnelForward,
                    implementations: [
                        Implementation(
                            name: String(localized: "\(name) Relay"),
                            type: .tunnelForwardRelay,
                            position: 0,
                            serverID: relayServer.id,
                            instanceID: relayServerInstance.id,
                            command: relayServerCommand,
                            fullCommand: relayServerFullCommand
                        ),
                        Implementation(
                            name: String(localized: "\(name) Destination"),
                            type: .tunnelForwardDestination,
                            position: 1,
                            serverID: destinationServer.id,
                            instanceID: destinationServerInstance.id,
                            command: destinationServerCommand,
                            fullCommand: destinationServerFullCommand
                        )
                    ]
                )
                context.insert(service)
                try? context.save()
                
                do {
                    // Update Instance Peer
                    async let updateRelayServerInstancePeer: () = instanceService.updateInstancePeer(
                        baseURLString: relayServer.url,
                        apiKey: relayServer.key,
                        id: relayServerInstance.id,
                        serviceAlias: String(localized: "\(name)"),
                        serviceId: serviceId.uuidString,
                        serviceType: "2"
                    )
                    async let updateDestinationServerInstancePeer: () = instanceService.updateInstancePeer(
                        baseURLString: destinationServer.url,
                        apiKey: destinationServer.key,
                        id: destinationServerInstance.id,
                        serviceAlias: String(localized: "\(name)"),
                        serviceId: serviceId.uuidString,
                        serviceType: "2"
                    )
                    
                    _ = try await (updateRelayServerInstancePeer, updateDestinationServerInstancePeer)
                }
                catch {
#if DEBUG
                    print("Error Updating Instance Peer Metadata: \(error.localizedDescription)")
#endif
                }
                
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
