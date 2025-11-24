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
    
    @State private var isAdvancedModeEnabled: Bool = NPCore.isAdvancedModeEnabled
    
    @State private var name: String = ""
    @State private var relayServer: Server?
    @State private var listenPort: String = ""
    @State private var destinationServer: Server?
    @State private var isExternalTarget: Bool = false
    @State private var externalTargetAddress: String = ""
    @State private var servicePort: String = ""
    @State private var tunnelPort: String = ""
    @State private var isTLS: Bool = false
    @State private var npServerLogLevel: LogLevel = .info
    @State private var npClientLogLevel: LogLevel = .info
    @State private var maximumPoolConnection: String = ""
    @State private var minimumPoolConnection: String = ""
    
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
                    LabeledTextField("Listen Port", prompt: "10022", text: $listenPort, isNumberOnly: true)
                    if isAdvancedModeEnabled {
                        Picker("Log Level", selection: $npClientLogLevel) {
                            ForEach(LogLevel.allCases, id: \.self) {
                                Text($0.rawValue)
                                    .tag($0)
                            }
                        }
                        LabeledTextField("Minimum Pool Connection", prompt: "64", text: $minimumPoolConnection, isNumberOnly: true)
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
                    Toggle("External Target", isOn: $isExternalTarget)
                    if isExternalTarget {
                        LabeledTextField("Target Address", prompt: "17.253.144.10", text: $externalTargetAddress)
                            .autocorrectionDisabled()
#if os(iOS)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
#endif
                        LabeledTextField("Target Port", prompt: "1080", text: $servicePort, isNumberOnly: true)
                    }
                    else {
                        LabeledTextField("Service Port", prompt: "1080", text: $servicePort, isNumberOnly: true)
                    }
                    LabeledTextField("Tunnel Port", prompt: "10101", text: $tunnelPort, isNumberOnly: true)
                    if isAdvancedModeEnabled {
                        Picker("Log Level", selection: $npServerLogLevel) {
                            ForEach(LogLevel.allCases, id: \.self) {
                                Text($0.rawValue)
                                    .tag($0)
                            }
                        }
                        LabeledTextField("Maximum Pool Connection", prompt: "1024", text: $maximumPoolConnection, isNumberOnly: true)
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
                        if isExternalTarget {
                            Text("Target Address: Address of your external target server.")
                            Text("Target Port: Port on which your service like Socks5(1080) is running on your external target server.")
                        }
                        Text("Tunnel Port: Any available port.")
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
        let listenPort = Int(listenPort) ?? 10022
        let externalTargetAddress = externalTargetAddress == "" ? "17.253.144.10" : externalTargetAddress
        let servicePort = Int(servicePort) ?? 1080
        let tunnelPort = Int(tunnelPort) ?? 10101
        
        var relayServerCommand: String
        // URL Base
        relayServerCommand = "client://\(destinationServer?.getHost() ?? ""):\(tunnelPort)/:\(listenPort)"
        // Core Confugurations
        relayServerCommand += "?mode=2"
        
        var destinationServerCommand: String
        // URL Base
        if isExternalTarget {
            destinationServerCommand = "server://:\(tunnelPort)/\(externalTargetAddress):\(servicePort)"
        }
        else {
            destinationServerCommand = "server://:\(tunnelPort)/127.0.0.1:\(servicePort)"
        }
        // Core Confugurations
        destinationServerCommand += "?mode=2"
        destinationServerCommand += isTLS ? "&tls=1" : "&tls=0"
        
        if isAdvancedModeEnabled {
            let maximumPoolConnection = Int(maximumPoolConnection) ?? 1024
            let minimumPoolConnection = Int(minimumPoolConnection) ?? 64
            // Advanced Confugurations
            relayServerCommand += "&log=\(npClientLogLevel.rawValue)"
            relayServerCommand += "&min=\(minimumPoolConnection)"
            // Advanced Confugurations
            destinationServerCommand += "&log=\(npServerLogLevel.rawValue)"
            destinationServerCommand += "&max=\(maximumPoolConnection)"
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
                        serviceType: isExternalTarget ? "4" : "2"
                    )
                    async let updateDestinationServerInstancePeer: () = instanceService.updateInstancePeer(
                        baseURLString: destinationServer.url,
                        apiKey: destinationServer.key,
                        id: destinationServerInstance.id,
                        serviceAlias: String(localized: "\(name)"),
                        serviceId: serviceId.uuidString,
                        serviceType: isExternalTarget ? "4" : "2"
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
