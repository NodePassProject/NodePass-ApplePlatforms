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
    
    @State private var name: String = ""
    @State private var client: Server?
    @State private var clientConnectPort: String = ""
    @State private var clientDestinationAddress: String = ""
    @State private var clientDestinationPort: String = ""
    
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
                    LabeledTextField("Address", prompt: "17.253.144.10", text: $clientDestinationAddress)
                        .autocorrectionDisabled()
#if os(iOS)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
#endif
                    LabeledTextField("Port", prompt: "1080", text: $clientDestinationPort, isNumberOnly: true)
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
                        let clientConnectPort = Int(clientConnectPort) ?? 1080
                        let clientDestinationPort = Int(clientDestinationPort) ?? 1080
                        
                        let command = "client://:\(clientConnectPort)/\(clientDestinationAddress):\(clientDestinationPort)?log=warn"
                        
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
    
    private func execute() {
        let client = client!
        
        let clientConnectPort = Int(clientConnectPort) ?? 1080
        let clientDestinationPort = Int(clientDestinationPort) ?? 1080
        
        let command = "client://:\(clientConnectPort)/\(clientDestinationAddress):\(clientDestinationPort)"
        
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
