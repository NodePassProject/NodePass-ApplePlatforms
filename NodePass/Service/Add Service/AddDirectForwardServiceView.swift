//
//  AddDirectForwardServiceView.swift
//  NodePass
//
//  Created by Junhui Lou on 7/4/25.
//

import SwiftUI
import SwiftData

struct AddDirectForwardServiceView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \Server.timestamp) private var servers: [Server]
    
    private var isAdvancedModeEnabled: Bool = NPCore.isAdvancedModeEnabled
    
    @State private var name: String = ""
    @State private var client: Server?
    @State private var clientConnectPort: String = ""
    @State private var clientDestinationAddress: String = ""
    @State private var clientDestinationPort: String = ""
    @State private var isLoadBalancing: Bool = false
    @State private var externalTargets: [ExternalTarget] = []
    @State private var logLevel: LogLevel = .info
    
    @State private var isShowErrorAlert: Bool = false
    @State private var errorMessage: String = ""
    @State private var isShowAddServerSheet: Bool = false
    @State private var newServer: Server?
    
    @State private var isSensoryFeedbackTriggered: Bool = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                }
                
                Section {
                    Picker("Server", selection: $client) {
                        Text("Select")
                            .tag(nil as Server?)
                        ForEach(servers) { server in
                            Text(server.name)
                                .tag(server)
                        }
                    }
                    LabeledTextField("Listen Port", prompt: "1080", text: $clientConnectPort, isNumberOnly: true)
                    if isAdvancedModeEnabled {
                        Picker("Log Level", selection: $logLevel) {
                            ForEach(LogLevel.allCases, id: \.self) {
                                Text($0.rawValue)
                                    .tag($0)
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text("Relay Server")
                        Spacer()
                        Button {
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
                    if isLoadBalancing {
                        ForEach(externalTargets) { externalTarget in
                            LabeledTextField(
                                "Address \(externalTarget.position + 1)",
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
                                "Port \(externalTarget.position + 1)",
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
                        LabeledTextField("Address", prompt: "17.253.144.10", text: $clientDestinationAddress)
                            .autocorrectionDisabled()
#if os(iOS)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
#endif
                        LabeledTextField("Port", prompt: "1080", text: $clientDestinationPort, isNumberOnly: true)
                    }
                    Button("Add Target", systemImage: "plus") {
                        if externalTargets.isEmpty {
                            externalTargets.append(ExternalTarget(position: 0, address: clientDestinationAddress, port: clientDestinationPort))
                            externalTargets.append(ExternalTarget(position: 1))
                            isLoadBalancing = true
                        }
                        else {
                            externalTargets.append(ExternalTarget(position: externalTargets.count))
                        }
                    }
                } header: {
                    Text("Destination Server")
                } footer: {
                    VStack(alignment: .leading) {
                        Text("Address: Domain/IP of the destination server.")
                        Text("Port: Port on which your service like Socks5(1080) is running.")
                    }
                }
                
                if #available(iOS 18.0, *) {
                    Section("Preview") {
                        let command = generateCommand()
                        
                        let name = NPCore.noEmptyName(name)
                        let previewService = Service(
                            name: name,
                            type: .directForward,
                            implementations: [
                                Implementation(
                                    name: String(localized: "\(name) Relay"),
                                    type: .directForwardClient,
                                    position: 0,
                                    serverID: client?.id ?? "",
                                    instanceID: "",
                                    command: command,
                                    fullCommand: command
                                )
                            ]
                        )
                        
                        DirectForwardCardView(service: previewService, isPreview: true)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Add Direct Forward")
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
                        .disabled(client == nil || clientDestinationAddress == "")
                    }
                    else {
                        Button("Done") {
                            dismiss()
                            execute()
                        }
                        .disabled(client == nil || clientDestinationAddress == "")
                    }
                }
            }
            .alert("Error", isPresented: $isShowErrorAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .sheet(isPresented: $isShowAddServerSheet) {
                client = newServer
            } content: {
                EditServerView(server: $newServer)
            }
            .sensoryFeedback(.success, trigger: isSensoryFeedbackTriggered)
        }
    }
    
    private func generateCommand() -> String {
        let clientConnectPort = Int(clientConnectPort) ?? 1080
        let clientDestinationAddress = clientDestinationAddress == "" ? "17.253.144.10" : clientDestinationAddress
        let clientDestinationPort = Int(clientDestinationPort) ?? 1080
        
        var command: String
        // URL Base
        if isLoadBalancing {
            let externalTargetAddressesAndPorts = externalTargets.map { "\($0.address):\($0.port)" }.joined(separator: ",")
            command = "client://:\(clientConnectPort)/\(externalTargetAddressesAndPorts)"
        }
        else {
            command = "client://:\(clientConnectPort)/\(clientDestinationAddress):\(clientDestinationPort)"
        }
        // Advanced Confugurations
        if isAdvancedModeEnabled {
            command += "?log=\(logLevel.rawValue)"
        }
        
        return command
    }
    
    private func execute() {
        let client = client!
        
        let command = generateCommand()
        
        Task {
            let instanceService = InstanceService()
            do {
                let clientInstance = try await instanceService.createInstance(
                    baseURLString: client.url,
                    apiKey: client.key,
                    url: command
                )
                
                let fullCommand = clientInstance.config ?? command
                
                let serviceId = UUID()
                let name = NPCore.noEmptyName(name)
                let service = Service(
                    id: serviceId,
                    name: name,
                    type: .directForward,
                    implementations: [
                        Implementation(
                            name: String(localized: "\(name) Relay"),
                            type: .directForwardClient,
                            position: 0,
                            serverID: client.id,
                            instanceID: clientInstance.id,
                            command: command,
                            fullCommand: fullCommand
                        )
                    ]
                )
                context.insert(service)
                try? context.save()
                
                do {
                    try await instanceService.updateInstancePeer(
                        baseURLString: client.url,
                        apiKey: client.key,
                        id: clientInstance.id,
                        serviceAlias: String(localized: "\(name)"),
                        serviceId: serviceId.uuidString,
                        serviceType: "0"
                    )
                } catch {
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
