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
                            Text(server.name!)
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
                    LabeledTextField("Port", prompt: "1080", text: $clientDestinationPort, isNumberOnly: true)
                } header: {
                    Text("Destination Server")
                } footer: {
                    VStack(alignment: .leading) {
                        Text("Destination Server: Server you want your traffic to relay to.")
                        Text("Address: Domain/IP of the destination server.")
                        Text("Port: Port on which your service like Socks5(1080) is running.")
                    }
                }
                
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
                                serverID: "",
                                instanceID: "",
                                command: command
                            )
                        ]
                    )
                    
                    DirectForwardCardView(service: previewService, isPreview: true)
                }
                
#if DEBUG
                Section {
                    Button("Sample") {
                        name = "Sample Direct Forward"
                        client = servers.first
                        clientConnectPort = "60004"
                        clientDestinationAddress = "17.253.144.10"
                        clientDestinationPort = "60004"
                    }
                }
#endif
            }
            .formStyle(.grouped)
            .navigationTitle("Add Direct Forward")
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
                    .disabled(client == nil || clientDestinationAddress == "")
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
        }
    }
    
    private func execute() {
        let clientConnectPort = Int(clientConnectPort) ?? 1080
        let clientDestinationPort = Int(clientDestinationPort) ?? 1080
        
        let command = "client://:\(clientConnectPort)/\(clientDestinationAddress):\(clientDestinationPort)?log=warn"

        Task {
            do {
                let clientInstanceService = InstanceService()
                let clientInstance = try await clientInstanceService.createInstance(
                    baseURLString: client!.url!,
                    apiKey: client!.key!,
                    url: command
                )
                
                let name = NPCore.noEmptyName(name)
                let service = Service(
                    name: name,
                    type: .directForward,
                    implementations: [
                        Implementation(
                            name: String(localized: "\(name) Relay"),
                            type: .directForwardClient,
                            position: 0,
                            serverID: client!.id!,
                            instanceID: clientInstance.id,
                            command: command
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
