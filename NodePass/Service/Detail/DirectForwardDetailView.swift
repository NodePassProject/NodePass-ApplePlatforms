//
//  DirectForwardDetailView.swift
//  NodePass
//
//  Created by Junhui Lou on 7/12/25.
//

import SwiftUI
import SwiftData

struct DirectForwardDetailView: View {
    @Environment(NPState.self) var state
    
    let service: Service
    
    @Query private var servers: [Server]
    
    var body: some View {
        if service.type == .directForward {
            Form {
                let implementation = service.implementations!.first(where: { $0.position == 0 })!
                let server = servers.first(where: { $0.id == implementation.serverID })
                let addressesAndPorts = implementation.extractAddressesAndPorts()
                
                if let server {
                    let connectionString = "\(server.getHost()):\(addressesAndPorts.tunnel.port)"
                    Section("You Should Connect To") {
                        Text(connectionString)
                    }
                    .copiable(connectionString)
                }
                
                Section("Relay Server") {
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
                        Text(addressesAndPorts.tunnel.port)
                    }
                    LabeledContent("Command URL") {
                        Text(implementation.command!)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                    }
                    .copiable(implementation.command!)
                }
                
                Section("Destination Server") {
                    LabeledContent("Address") {
                        Text(addressesAndPorts.destination.address)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                    }
                    .copiable(addressesAndPorts.destination.address)
                    LabeledContent("Port") {
                        Text(addressesAndPorts.destination.port)
                    }
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
