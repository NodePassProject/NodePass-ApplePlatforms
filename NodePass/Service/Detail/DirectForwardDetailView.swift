//
//  DirectForwardDetailView.swift
//  NodePass
//
//  Created by Junhui Lou on 7/12/25.
//

import SwiftUI
import SwiftData
import Drops

struct DirectForwardDetailView: View {
    @Environment(NPState.self) var state
    
    let service: Service
    var implementation: Implementation {
        service.implementations!.first(where: { $0.position == 0 })!
    }
    var server: Server? {
        servers.first(where: { $0.id == implementation.serverID })
    }
    
    @Query private var servers: [Server]
    
    @State private var instance: Instance?
    @State private var isShowEditInstanceSheet: Bool = false
    
    @State private var isShowErrorAlert: Bool = false
    @State private var errorMessage: String = ""
    
    var body: some View {
        if service.type == .directForward {
            Form {
                Section("Relay Server") {
                    if let server {
                        VStack {
                            ServerCardView(server: server)
                                .onTapGesture {
                                    state.tab = .servers
                                    state.pathServers.append(server)
                                }
                        }
                        .frame(maxWidth: .infinity)
                        
                        if let instance {
                            VStack {
                                InstanceCardView(instance: instance)
                                    .onTapGesture {
                                        isShowEditInstanceSheet = true
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
                fetchInstance()
            }
            .sheet(isPresented: $isShowEditInstanceSheet) {
                if let server, let instance {
                    EditInstanceView(server: server, instance: instance) {
                        fetchInstance()
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
    
    private func fetchInstance() {
        guard let server else { return }
        Task {
            let instanceService = InstanceService()
            do {
                let instances = try await instanceService.listInstances(baseURLString: server.url, apiKey: server.key)
                self.instance = instances.first(where: { $0.id == implementation.instanceID })
            }
            catch {
#if DEBUG
                print("Error Fetching Instance: \(error.localizedDescription)")
#endif
            }
        }
    }
}
