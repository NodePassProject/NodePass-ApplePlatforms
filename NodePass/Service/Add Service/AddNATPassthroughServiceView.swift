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
    
    private var isAdvancedModeEnabled: Bool = NPCore.isAdvancedModeEnabled
    
    @State private var name: String = ""
    @State private var remoteServer: Server?
    @State private var listenPort: String = ""
    @State private var tunnelPort: String = ""
    @State private var localServer: Server?
    @State private var isExternalTarget: Bool = false
    @State private var externalTargetAddress: String = ""
    @State private var servicePort: String = ""
    @State private var isLoadBalancing: Bool = false
    @State private var externalTargets: [ExternalTarget] = []
    @State private var transport: Instance.Transport = .tcp
    @State private var isTLS: Bool = false
    @State private var npServerLogLevel: LogLevel = .info
    @State private var npClientLogLevel: LogLevel = .info
    @State private var maximumPoolConnection: String = ""
    @State private var minimumPoolConnection: String = ""
    @State private var isTCPDisabled: Bool = false
    @State private var isUDPDisabled: Bool = false
    
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
                    Picker("Server", selection: $remoteServer) {
                        Text("Select")
                            .tag(nil as Server?)
                        ForEach(servers) { server in
                            Text(server.name)
                                .tag(server)
                        }
                    }
                    LabeledTextField("Listen Port", prompt: "10022", text: $listenPort, isNumberOnly: true)
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
                        Text("Remote Server")
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
                    Picker("Server", selection: $localServer) {
                        Text("Select")
                            .tag(nil as Server?)
                        ForEach(servers) { server in
                            Text(server.name)
                                .tag(server)
                        }
                    }
                    Toggle("External Target", isOn: $isExternalTarget)
                        .onChange(of: isExternalTarget) {
                            if isExternalTarget == false {
                                externalTargets.removeAll()
                                isLoadBalancing = false
                            }
                        }
                    if isExternalTarget {
                        if isLoadBalancing {
                            ForEach(externalTargets) { externalTarget in
                                LabeledTextField(
                                    "Target Address \(externalTarget.position + 1)",
                                    prompt: "17.253.144.10",
                                    text: Binding(get: {
                                        externalTargets[externalTarget.position].address
                                    }, set: {
                                        externalTargets[externalTarget.position].address = $0
                                    })
                                )
                                .autocorrectionDisabled()
#if os(iOS)
                                .textInputAutocapitalization(.never)
                                .keyboardType(.URL)
#endif
                                LabeledTextField(
                                    "Target Port \(externalTarget.position + 1)",
                                    prompt: "1080",
                                    text: Binding(get: {
                                        externalTargets[externalTarget.position].port
                                    }, set: {
                                        externalTargets[externalTarget.position].port = $0
                                    }),
                                    isNumberOnly: true
                                )
                            }
                        }
                        else {
                            LabeledTextField("Target Address", prompt: "17.253.144.10", text: $externalTargetAddress)
                                .autocorrectionDisabled()
#if os(iOS)
                                .textInputAutocapitalization(.never)
                                .keyboardType(.URL)
#endif
                            LabeledTextField("Target Port", prompt: "1080", text: $servicePort, isNumberOnly: true)
                        }
                        HStack(spacing: 5) {
                            Button {
                                if externalTargets.isEmpty {
                                    externalTargets.append(ExternalTarget(position: 0, address: externalTargetAddress, port: servicePort))
                                    externalTargets.append(ExternalTarget(position: 1))
                                    isLoadBalancing = true
                                }
                                else {
                                    externalTargets.append(ExternalTarget(position: externalTargets.count))
                                }
                            } label: {
                                Image(systemName: "plus")
                                    .frame(width: 20, height: 20)
                            }
#if os(iOS)
                            .buttonBorderShape(.circle)
                            .buttonStyle(.borderedProminent)
#else
                            .buttonStyle(.borderless)
#endif
                            Button(role: .destructive) {
                                if externalTargets.count == 2 {
                                    externalTargets.removeAll()
                                    isLoadBalancing = false
                                }
                                else {
                                    externalTargets.remove(at: externalTargets.endIndex - 1)
                                }
                            } label: {
                                Image(systemName: "minus")
                                    .frame(width: 20, height: 20)
                            }
                            .disabled(externalTargets.count < 2)
#if os(iOS)
                            .buttonBorderShape(.circle)
                            .buttonStyle(.borderedProminent)
#else
                            .buttonStyle(.borderless)
#endif
                        }
                    }
                    else {
                        LabeledTextField("Service Port", prompt: "1080", text: $servicePort, isNumberOnly: true)
                    }
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
                        Text("Local Server")
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
                        if isExternalTarget {
                            Text("Target Address: Address of your external target like devices in your home.")
                            Text("Target Port: Port on which your service like SSH(22) is running on your external target.")
                        }
                        else {
                            Text("Service Port: Port on which your service like SSH(22) is running.")
                        }
                    }
                }
                
                Section("Transport") {
                    Picker("Protocol", selection: $transport) {
                        ForEach(Instance.Transport.allCases, id: \.self) {
                            Text($0.localizedName)
                                .tag($0)
                        }
                    }
                    .onChange(of: transport) { oldValue, newValue in
                        if transport.isRequireTLS {
                            isTLS = true
                        }
                    }
                    Toggle("TLS", isOn: $isTLS)
                        .disabled(transport.isRequireTLS)
                    if isAdvancedModeEnabled {
                        Toggle("Disable TCP", isOn: $isTCPDisabled)
                        Toggle("Disable UDP", isOn: $isUDPDisabled)
                    }
                }
                
                if #available(iOS 18.0, *) {
                    Section("Preview") {
                        let (serverCommand, clientCommand) = generateCommands()
                        
                        let name = NPCore.noEmptyName(name)
                        let previewService = Service(
                            name: name,
                            type: .natPassthrough,
                            implementations: [
                                Implementation(
                                    name: String(localized: "\(name) Remote"),
                                    type: .natPassthroughServer,
                                    position: 0,
                                    serverID: remoteServer?.id ?? "",
                                    instanceID: "",
                                    command: serverCommand,
                                    fullCommand: serverCommand
                                ),
                                Implementation(
                                    name: String(localized: "\(name) Local"),
                                    type: .natPassthroughClient,
                                    position: 1,
                                    serverID: localServer?.id ?? "",
                                    instanceID: "",
                                    command: clientCommand,
                                    fullCommand: clientCommand
                                )
                            ]
                        )
                        
                        NATPassthroughCardView(service: previewService, isPreview: true)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Add NAT Passthrough")
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
                        .disabled(remoteServer == nil || localServer == nil)
                    }
                    else {
                        Button("Done") {
                            dismiss()
                            execute()
                        }
                        .disabled(remoteServer == nil || localServer == nil)
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
                    remoteServer = newServer
                }
                if isAddingClient {
                    localServer = newServer
                }
            } content: {
                EditServerView(server: $newServer)
            }
            .sensoryFeedback(.success, trigger: isSensoryFeedbackTriggered)
        }
    }
    
    private func generateCommands() -> (serverCommand: String, clientCommand: String) {
        let listenPort = Int(listenPort) ?? 10022
        let externalTargetAddress = externalTargetAddress == "" ? "192.168.1.1" : externalTargetAddress
        let servicePort = Int(servicePort) ?? 22
        let tunnelPort = Int(tunnelPort) ?? 10101
        
        var serverCommand: String
        // URL Base
        serverCommand = "server://:\(tunnelPort)/:\(listenPort)"
        // Core Confugurations
        serverCommand += "?mode=1"
        serverCommand += "&type=\(transport.rawValue)"
        serverCommand += isTLS ? "&tls=1" : "&tls=0"
        serverCommand += isTCPDisabled ? "&notcp=1" : ""
        serverCommand += isUDPDisabled ? "&noudp=1" : ""
        
        var clientCommand: String
        // URL Base
        if isExternalTarget {
            if isLoadBalancing {
                let externalTargetAddressesAndPorts = externalTargets.map { "\($0.address):\($0.port)" }.joined(separator: ",")
                clientCommand = "client://\(remoteServer?.getHost() ?? ""):\(tunnelPort)/\(externalTargetAddressesAndPorts)"
            }
            else {
                clientCommand = "client://\(remoteServer?.getHost() ?? ""):\(tunnelPort)/\(externalTargetAddress):\(servicePort)"
            }
        }
        else {
            clientCommand = "client://\(remoteServer?.getHost() ?? ""):\(tunnelPort)/127.0.0.1:\(servicePort)"
        }
        // Core Confugurations
        clientCommand += "?mode=2"
        
        if isAdvancedModeEnabled {
            let maximumPoolConnection = Int(maximumPoolConnection) ?? 1024
            let minimumPoolConnection = Int(minimumPoolConnection) ?? 64
            // Advanced Confugurations
            serverCommand += "&log=\(npServerLogLevel.rawValue)"
            serverCommand += "&max=\(maximumPoolConnection)"
            // Advanced Confugurations
            clientCommand += "&log=\(npClientLogLevel.rawValue)"
            clientCommand += "&min=\(minimumPoolConnection)"
        }
        
        return (serverCommand, clientCommand)
    }
    
    private func execute() {
        let remoteServer = remoteServer!
        let localServer = localServer!
        
        let commands = generateCommands()
        let serverCommand = commands.serverCommand
        let clientCommand = commands.clientCommand
        
        Task {
            let instanceService = InstanceService()
            do {
                async let createServerInstance: (Instance) = instanceService.createInstance(
                    baseURLString: remoteServer.url,
                    apiKey: remoteServer.key,
                    url: serverCommand
                )
                async let createClientInstance: (Instance) = instanceService.createInstance(
                    baseURLString: localServer.url,
                    apiKey: localServer.key,
                    url: clientCommand
                )
                
                let (serverInstance, clientInstance) = try await (createServerInstance, createClientInstance)
                
                let serverFullCommand = serverInstance.config ?? serverCommand
                let clientFullCommand = clientInstance.config ?? clientCommand
                
                let serviceId = UUID()
                let name = NPCore.noEmptyName(name)
                let service = Service(
                    id: serviceId,
                    name: name,
                    type: .natPassthrough,
                    implementations: [
                        Implementation(
                            name: String(localized: "\(name) Remote"),
                            type: .natPassthroughServer,
                            position: 0,
                            serverID: remoteServer.id,
                            instanceID: serverInstance.id,
                            command: serverCommand,
                            fullCommand: serverFullCommand
                        ),
                        Implementation(
                            name: String(localized: "\(name) Local"),
                            type: .natPassthroughClient,
                            position: 1,
                            serverID: localServer.id,
                            instanceID: clientInstance.id,
                            command: clientCommand,
                            fullCommand: clientFullCommand
                        )
                    ]
                )
                context.insert(service)
                try? context.save()
                
                do {
                    // Update Instance Peer
                    async let updateServerInstancePeer: () = instanceService.updateInstancePeer(
                        baseURLString: remoteServer.url,
                        apiKey: remoteServer.key,
                        id: serverInstance.id,
                        serviceAlias: String(localized: "\(name)"),
                        serviceId: serviceId.uuidString,
                        serviceType: isExternalTarget ? "3" : "1"
                    )
                    async let updateClientInstancePeer: () = instanceService.updateInstancePeer(
                        baseURLString: localServer.url,
                        apiKey: localServer.key,
                        id: clientInstance.id,
                        serviceAlias: String(localized: "\(name)"),
                        serviceId: serviceId.uuidString,
                        serviceType: isExternalTarget ? "3" : "1"
                    )
                    
                    _ = try await (updateServerInstancePeer, updateClientInstancePeer)
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
