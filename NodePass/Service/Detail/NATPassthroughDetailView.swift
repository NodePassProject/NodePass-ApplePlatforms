//
//  NATPassthroughDetailView.swift
//  NodePass
//
//  Created by Junhui Lou on 7/12/25.
//

import SwiftUI
import SwiftData

fileprivate enum EditPortOption {
    case tunnel
    case destination
}

struct NATPassthroughDetailView: View {
    @Environment(NPState.self) var state
    
    let service: Service
    var implementation0: Implementation {
        service.implementations!.first(where: { $0.position == 0 })!
    }
    var server0: Server? {
        servers.first(where: { $0.id == implementation0.serverID })
    }
    var addressesAndPorts0: (tunnel: (address: String, port: String), destination: (address: String, port: String)) {
        implementation0.parseAddressesAndPorts()
    }
    var queryParameters0: [String: String] {
        implementation0.parseQueryParameters()
    }
    var implementation1: Implementation {
        service.implementations!.first(where: { $0.position == 1 })!
    }
    var server1: Server? {
        servers.first(where: { $0.id == implementation1.serverID })
    }
    var addressesAndPorts1: (tunnel: (address: String, port: String), destination: (address: String, port: String)) {
        implementation1.parseAddressesAndPorts()
    }
    
    @Query private var servers: [Server]
    
    @State private var isShowEditPortAlert: Bool = false
    private var editPortAlertTitle: String {
        switch(editPortOption) {
        case .tunnel:
            return String(localized: "Edit Tunnel Port")
        case .destination:
            if implementationToEdit == implementation0 {
                return String(localized: "Edit Listen Port")
            }
            if implementationToEdit == implementation1 {
                return String(localized: "Edit Service Port")
            }
            return ""
        }
    }
    @State private var newPort: String = ""
    @State private var editPortOption: EditPortOption = .destination
    @State private var implementationToEdit: Implementation?
    
    @State private var isShowErrorAlert: Bool = false
    @State private var errorMessage: String = ""
    
    var body: some View {
        if service.type == .natPassthrough {
            Form {
                if let server = server0 {
                    let connectionString = "\(server.getHost()):\(addressesAndPorts0.destination.port)"
                    Section("You Should Connect To") {
                        Text(connectionString)
                    }
                    .copiable(connectionString)
                }
                
                Section("Remote Server (with Public IP)") {
                    let implementation = implementation0
                    let server = server0
                    let addressesAndPorts = addressesAndPorts0
                    let queryParameters = queryParameters0
                    
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
                            Text(addressesAndPorts.destination.port)
                        }
                        if server != nil {
                            Button {
                                editPortOption = .destination
                                implementationToEdit = implementation0
                                isShowEditPortAlert = true
                            } label: {
                                Image(systemName: "pencil")
                            }
                        }
                    }
                    .copiable(addressesAndPorts.destination.port)
                    HStack {
                        LabeledContent("Tunnel Port") {
                            Text(addressesAndPorts.tunnel.port)
                        }
                        if server0 != nil && server1 != nil {
                            Button {
                                editPortOption = .tunnel
                                implementationToEdit = nil
                                isShowEditPortAlert = true
                            } label: {
                                Image(systemName: "pencil")
                            }
                        }
                    }
                    .copiable(addressesAndPorts.tunnel.port)
                    if let tlsLevel = queryParameters["tls"] {
                        LabeledContent("TLS Level") {
                            Text(NPCore.localizedTLSLevel(tlsLevel: tlsLevel))
                        }
                    }
                    LabeledContent("Command URL") {
                        Text(implementation.command!)
                    }
                    .copiable(implementation.command!)
                }
                
                Section("Local Server (Behind NAT)") {
                    let implementation = implementation1
                    let server = server1
                    let addressesAndPorts = addressesAndPorts1
                    
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
                        LabeledContent("Service Port") {
                            Text(addressesAndPorts.destination.port)
                        }
                        if server != nil {
                            Button {
                                editPortOption = .destination
                                implementationToEdit = implementation1
                                isShowEditPortAlert = true
                            } label: {
                                Image(systemName: "pencil")
                            }
                        }
                    }
                    .copiable(addressesAndPorts.destination.port)
                    HStack {
                        LabeledContent("Tunnel Port") {
                            Text(addressesAndPorts.tunnel.port)
                        }
                        if server0 != nil && server1 != nil {
                            Button {
                                editPortOption = .tunnel
                                implementationToEdit = nil
                                isShowEditPortAlert = true
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
            }
            .formStyle(.grouped)
            .navigationTitle(service.name!)
            .alert(editPortAlertTitle, isPresented: $isShowEditPortAlert) {
                TextField("Port", text: $newPort)
                Button("OK") {
                    updateImplementation(implementation: implementationToEdit, editPortOption: editPortOption, newPort: newPort)
                    newPort = ""
                }
                Button("Cancel", role: .cancel) {
                    newPort = ""
                }
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
    
    private func updateImplementation(implementation: Implementation?, editPortOption: EditPortOption, newPort: String) {
        Task {
            let instanceService = InstanceService()
            do {
                switch(editPortOption) {
                case .tunnel:
                    let server0 = servers.first(where: { $0.id == implementation0.serverID })!
                    let command0 = implementation0.dryModifyTunnelPort(port: newPort)
                    async let updateInstance0: () = instanceService.updateInstance(baseURLString: server0.url!, apiKey: server0.key!, id: implementation0.instanceID!, url: command0)
                    
                    let server1 = servers.first(where: { $0.id == implementation1.serverID })!
                    let command1 = implementation1.dryModifyTunnelPort(port: newPort)
                    async let updateInstance1: () = instanceService.updateInstance(baseURLString: server1.url!, apiKey: server1.key!, id: implementation1.instanceID!, url: command1)
                    
                    _ = try await (updateInstance0, updateInstance1)
                    
                    implementation0.command = command0
                    implementation1.command = command1
                case .destination:
                    let implementation = implementation!
                    let server = servers.first(where: { $0.id == implementation.serverID })!
                    let command = implementation.dryModifyDestinationPort(port: newPort)
                    try await instanceService.updateInstance(baseURLString: server.url!, apiKey: server.key!, id: implementation.instanceID!, url: command)
                    implementation.command = command
                }
            }
            catch {
                errorMessage = "Error Updating Instances: \(error.localizedDescription)"
                isShowErrorAlert = true
            }
        }
    }
}
