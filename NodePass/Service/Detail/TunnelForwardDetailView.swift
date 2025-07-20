//
//  TunnelForwardDetailView.swift
//  NodePass
//
//  Created by Junhui Lou on 7/12/25.
//

import SwiftUI
import SwiftData

struct TunnelForwardDetailView: View {
    @Environment(NPState.self) var state
    
    let service: Service
    
    @Query private var servers: [Server]
    
    var body: some View {
        if service.type == .tunnelForward {
            Form {
                let implementation0 = service.implementations!.first(where: { $0.position == 0 })!
                let server0 = servers.first(where: { $0.id == implementation0.serverID })
                let addressesAndPorts0 = implementation0.extractAddressesAndPorts()
                let queryParameters0 = implementation0.extractQueryParameters()
                let implementation1 = service.implementations!.first(where: { $0.position == 1 })!
                let server1 = servers.first(where: { $0.id == implementation1.serverID })
                let addressesAndPorts1 = implementation1.extractAddressesAndPorts()
                
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
                    
                    HStack {
                        if let server {
                            LabeledContent("Server") {
                                Text(server.name!)
                            }
                            Button {
                                state.tab = .servers
                                state.pathServers.append(server)
                            } label: {
                                Image(systemName: "list.dash.header.rectangle")
                            }
                        }
                        else {
                            LabeledContent("Server") {
                                Text("Not on this device")
                            }
                        }
                    }
                    LabeledContent("Listen Port") {
                        Text(addressesAndPorts.destination.port)
                    }
                    LabeledContent("Tunnel Port") {
                        Text(addressesAndPorts.tunnel.port)
                    }
                    LabeledContent("TLS Level") {
                        Text(queryParameters["tls"]!)
                    }
                    LabeledContent("Command URL") {
                        Text(implementation.command!)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                    }
                    .copiable(implementation.command!)
                }
                
                Section("Destination Server") {
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
                                Image(systemName: "list.dash.header.rectangle")
                            }
                        }
                        else {
                            LabeledContent("Server") {
                                Text("Not on this device")
                            }
                        }
                    }
                    LabeledContent("Service Port") {
                        Text(addressesAndPorts.destination.port)
                    }
                    LabeledContent("Tunnel Port") {
                        Text(addressesAndPorts.tunnel.port)
                    }
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
        }
        else {
            Image(systemName: "exclamationmark.circle")
                .foregroundStyle(.red)
        }
    }
}
