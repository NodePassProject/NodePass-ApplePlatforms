//
//  DirectForwardDetailView.swift
//  NodePass
//
//  Created by Junhui Lou on 7/12/25.
//

import SwiftUI
import SwiftData

struct DirectForwardDetailView: View {
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
                    .copiable(string: connectionString)
                }
                
                Section("Relay Server") {
                    LabeledContent("Server") {
                        if let server {
                            Text(server.name!)
                        }
                        else {
                            Text("Not on this device")
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
                    .copiable(string: implementation.command!)
                }
                
                Section("Destination Server") {
                    LabeledContent("Address") {
                        Text(addressesAndPorts.destination.address)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                    }
                    .copiable(string: addressesAndPorts.destination.address)
                    LabeledContent("Port") {
                        Text(addressesAndPorts.destination.port)
                    }
                }
            }
            .navigationTitle(service.name!)
        }
        else {
            Image(systemName: "exclamationmark.circle")
                .foregroundStyle(.red)
        }
    }
}
