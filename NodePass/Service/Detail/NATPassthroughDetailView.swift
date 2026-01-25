//
//  NATPassthroughDetailView.swift
//  NodePass
//
//  Created by Junhui Lou on 7/12/25.
//

import SwiftUI
import SwiftData
import Drops

struct NATPassthroughDetailView: View {
    @Environment(NPState.self) var state
    
    let service: Service
    var implementation0: Implementation {
        service.implementations!.first(where: { $0.position == 0 })!
    }
    var server0: Server? {
        servers.first(where: { $0.id == implementation0.serverID })
    }
    var implementation1: Implementation {
        service.implementations!.first(where: { $0.position == 1 })!
    }
    var server1: Server? {
        servers.first(where: { $0.id == implementation1.serverID })
    }
    
    @Query private var servers: [Server]
    
    @State private var instance0: Instance?
    @State private var instance1: Instance?
    @State private var isShowEditInstance0Sheet: Bool = false
    @State private var isShowEditInstance1Sheet: Bool = false
    
    @State private var isShowErrorAlert: Bool = false
    @State private var errorMessage: String = ""
    
    var body: some View {
        if service.type == .natPassthrough {
            Form {
                Section("Remote Server") {
                    let server = server0
                    
                    if let server {
                        VStack {
                            ServerCardView(server: server)
                                .onTapGesture {
                                    state.tab = .servers
                                    state.pathServers.append(server)
                                }
                        }
                        .frame(maxWidth: .infinity)
                        
                        if let instance0 {
                            VStack {
                                InstanceCardView(instance: instance0)
                                    .onTapGesture {
                                        isShowEditInstance0Sheet = true
                                    }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        else {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        }
                    }
                    else {
                        LabeledContent("Server") {
                            Text("Not on this device")
                        }
                    }
                }
                
                Section("Local Server") {
                    let server = server1
                    
                    if let server {
                        VStack {
                            ServerCardView(server: server)
                                .onTapGesture {
                                    state.tab = .servers
                                    state.pathServers.append(server)
                                }
                        }
                        .frame(maxWidth: .infinity)
                        
                        if let instance1 {
                            VStack {
                                InstanceCardView(instance: instance1)
                                    .onTapGesture {
                                        isShowEditInstance1Sheet = true
                                    }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        else {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        }
                    }
                    else {
                        LabeledContent("Server") {
                            Text("Not on this device")
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(service.name)
            .onAppear {
                fetchInstances()
            }
            .sheet(isPresented: $isShowEditInstance0Sheet) {
                if let server0, let instance0 {
                    EditInstanceView(server: server0, instance: instance0) {
                        fetchInstances()
                    }
                }
            }
            .sheet(isPresented: $isShowEditInstance1Sheet) {
                if let server1, let instance1 {
                    EditInstanceView(server: server1, instance: instance1) {
                        fetchInstances()
                    }
                }
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
    
    private func fetchInstances() {
        if let server0 {
            Task {
                let instanceService = InstanceService()
                do {
                    let instances = try await instanceService.listInstances(baseURLString: server0.url, apiKey: server0.key)
                    self.instance0 = instances.first(where: { $0.id == implementation0.instanceID })
                }
                catch {
#if DEBUG
                    print("Error Fetching Instance 0: \(error.localizedDescription)")
#endif
                }
            }
        }
        if let server1 {
            Task {
                let instanceService = InstanceService()
                do {
                    let instances = try await instanceService.listInstances(baseURLString: server1.url, apiKey: server1.key)
                    self.instance1 = instances.first(where: { $0.id == implementation1.instanceID })
                }
                catch {
#if DEBUG
                    print("Error Fetching Instance 1: \(error.localizedDescription)")
#endif
                }
            }
        }
    }
}
