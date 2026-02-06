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
    @State private var instanceLoadingState: LoadingState = .loading
    @State private var isShowEditInstanceSheet: Bool = false
    
    @State private var isShowErrorAlert: Bool = false
    @State private var errorMessage: String = ""
    
    enum LoadingState {
        case loading
        case loaded
        case notFound
    }
    
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
                        
                        switch instanceLoadingState {
                        case .loading:
                            ProgressView()
                                .listRowSeparator(.hidden)
                                .frame(maxWidth: .infinity)
                        case .loaded:
                            if let instance {
                                VStack {
                                    InstanceCardView(instance: instance)
                                        .onTapGesture {
                                            isShowEditInstanceSheet = true
                                        }
                                }
                                .listRowSeparator(.hidden)
                                .frame(maxWidth: .infinity)
                            }
                        case .notFound:
                            Label("Instance Not Found", systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                                .listRowSeparator(.hidden)
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
        instanceLoadingState = .loading
        Task {
            let instanceService = InstanceService()
            do {
                let instances = try await instanceService.listInstances(baseURLString: server.url, apiKey: server.key)
                if let foundInstance = instances.first(where: { $0.id == implementation.instanceID }) {
                    await MainActor.run {
                        self.instance = foundInstance
                        self.instanceLoadingState = .loaded
                    }
                } else {
                    await MainActor.run {
                        self.instance = nil
                        self.instanceLoadingState = .notFound
                    }
                }
            }
            catch {
#if DEBUG
                print("Error Fetching Instance: \(error.localizedDescription)")
#endif
                await MainActor.run {
                    self.instanceLoadingState = .notFound
                }
            }
        }
    }
}
