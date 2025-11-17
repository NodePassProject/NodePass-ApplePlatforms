//
//  TunnelForwardDetailView.swift
//  NodePass
//
//  Created by Junhui Lou on 7/12/25.
//

import SwiftUI
import SwiftData
import Drops

fileprivate enum EditPortOption {
    case tunnel
    case destination
}

struct TunnelForwardDetailView: View {
    @Environment(NPState.self) var state
    
    let service: Service
    var implementation0: Implementation {
        service.implementations!.first(where: { $0.position == 0 })!
    }
    var server0: Server? {
        servers.first(where: { $0.id == implementation0.serverID })
    }
    var addressesAndPorts0: (tunnel: (address: String, port: String), destination: (address: String, port: String)) {
        NPCore.parseAddressesAndPorts(urlString: implementation0.command)
    }
    var queryParameters0: [String: String] {
        NPCore.parseQueryParameters(urlString: implementation0.fullCommand, isFull: true)
    }
    var implementation1: Implementation {
        service.implementations!.first(where: { $0.position == 1 })!
    }
    var server1: Server? {
        servers.first(where: { $0.id == implementation1.serverID })
    }
    var addressesAndPorts1: (tunnel: (address: String, port: String), destination: (address: String, port: String)) {
        NPCore.parseAddressesAndPorts(urlString: implementation1.command)
    }
    var queryParameters1: [String: String] {
        NPCore.parseQueryParameters(urlString: implementation1.fullCommand, isFull: true)
    }
    
    @Query private var servers: [Server]
    
    @State private var isShowEditAddressAlert: Bool = false
    @State private var newAddress: String = ""
    
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
    
    @State private var isSensoryFeedbackTriggered: Bool = false
    
    var body: some View {
        if [.tunnelForward, .tunnelForwardExternal].contains(service.type) {
            Form {
                if let server = server0 {
                    let connectionString = "\(server.getHost()):\(addressesAndPorts0.destination.port)"
                    Section("You Should Connect To") {
                        Text(connectionString)
                    }
                    .copiable(connectionString)
                }
                
                Section("Relay Server") {
                    let implementation = implementation0
                    let server = server0
                    let addressesAndPorts = addressesAndPorts0
                    let queryParameters = queryParameters0
                    
                    if let server {
                        VStack {
                            ServerCardView(server: server)
                                .onTapGesture {
                                    state.tab = .servers
                                    state.pathServers.append(server)
                                }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    else {
                        LabeledContent("Server") {
                            Text("Not on this device")
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
                        Text(implementation.command)
                            .minimumScaleFactor(0.5)
                    }
                    .copiable(implementation.command)
                }
                
                Section("Destination Server") {
                    let implementation = implementation1
                    let server = server1
                    let addressesAndPorts = addressesAndPorts1
                    let queryParameters = queryParameters1
                    
                    if let server {
                        VStack {
                            ServerCardView(server: server)
                                .onTapGesture {
                                    state.tab = .servers
                                    state.pathServers.append(server)
                                }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    else {
                        LabeledContent("Server") {
                            Text("Not on this device")
                        }
                    }
                    if addressesAndPorts.destination.address == "127.0.0.1" {
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
                    }
                    else {
                        HStack {
                            LabeledContent("Target Address") {
                                Text(addressesAndPorts.destination.address)
                            }
                            if server != nil {
                                Button {
                                    isShowEditAddressAlert = true
                                } label: {
                                    Image(systemName: "pencil")
                                }
                            }
                        }
                        .copiable(addressesAndPorts.destination.address)
                        HStack {
                            LabeledContent("Target Port") {
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
                    }
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
                        Text(implementation.command)
                            .minimumScaleFactor(0.5)
                    }
                    .copiable(implementation.command)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(service.name)
            .alert("Edit Address", isPresented: $isShowEditAddressAlert) {
                TextField("Address", text: $newAddress)
                    .autocorrectionDisabled()
#if os(iOS)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
#endif
                Button("OK") {
                    updateImplementation(newAddress: newAddress)
                    newAddress = ""
                }
                Button("Cancel", role: .cancel) {
                    newAddress = ""
                }
            } message: {
                Text("Enter a new address.")
            }
            .alert(editPortAlertTitle, isPresented: $isShowEditPortAlert) {
                TextField("Port", text: $newPort)
#if os(iOS)
                    .keyboardType(.numberPad)
#endif
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
            .sensoryFeedback(.success, trigger: isSensoryFeedbackTriggered)
        }
        else {
            Image(systemName: "exclamationmark.circle")
                .foregroundStyle(.red)
        }
    }
    
    private func updateImplementation(newAddress: String) {
        Task {
            let instanceService = InstanceService()
            do {
                let implementation = implementation1
                let server = servers.first(where: { $0.id == implementation.serverID })!
                let command = implementation.dryModifyDestinationAddress(address: newAddress)
                let updatedInstance = try await instanceService.updateInstance(baseURLString: server.url, apiKey: server.key, id: implementation.instanceID, url: command)
                
                implementation.command = command
                implementation.fullCommand = updatedInstance.config ?? command
            }
            catch {
#if DEBUG
                print("Error Updating Instances: \(error.localizedDescription)")
#endif
                errorMessage = error.localizedDescription
                isShowErrorAlert = true
            }
        }
    }
    
    private func updateImplementation(implementation: Implementation?, editPortOption: EditPortOption, newPort: String) {
        Task {
            let instanceService = InstanceService()
            do {
                switch(editPortOption) {
                case .tunnel:
                    let implementation0 = implementation0
                    let server0 = servers.first(where: { $0.id == implementation0.serverID })!
                    let command0 = implementation0.dryModifyTunnelPort(port: newPort)
                    async let updateInstance0: (Instance) = instanceService.updateInstance(baseURLString: server0.url, apiKey: server0.key, id: implementation0.instanceID, url: command0)
                    
                    let implementation1 = implementation1
                    let server1 = servers.first(where: { $0.id == implementation1.serverID })!
                    let command1 = implementation1.dryModifyTunnelPort(port: newPort)
                    async let updateInstance1: (Instance) = instanceService.updateInstance(baseURLString: server1.url, apiKey: server1.key, id: implementation1.instanceID, url: command1)
                    
                    let (updatedInstance0, updatedInstance1) = try await (updateInstance0, updateInstance1)
                    
                    implementation0.command = command0
                    implementation0.fullCommand = updatedInstance0.config ?? command0
                    implementation1.command = command1
                    implementation1.fullCommand = updatedInstance1.config ?? command1
                case .destination:
                    let implementation = implementation!
                    let server = servers.first(where: { $0.id == implementation.serverID })!
                    let command = implementation.dryModifyDestinationPort(port: newPort)
                    let updatedInstance = try await instanceService.updateInstance(baseURLString: server.url, apiKey: server.key, id: implementation.instanceID, url: command)
                    
                    implementation.command = command
                    implementation.fullCommand = updatedInstance.config ?? command
                }
                
#if os(iOS)
                let drop = Drop(title: String(localized: "Success"), subtitle: String(localized: "Changes are now effective"), icon: UIImage(systemName: "checkmark.circle"))
                Drops.show(drop)
#endif
                isSensoryFeedbackTriggered.toggle()
            }
            catch {
#if DEBUG
                print("Error Updating Instances: \(error.localizedDescription)")
#endif
                errorMessage = error.localizedDescription
                isShowErrorAlert = true
            }
        }
    }
}
