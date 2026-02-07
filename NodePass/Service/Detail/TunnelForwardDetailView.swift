//
//  TunnelForwardDetailView.swift
//  NodePass
//
//  Created by Junhui Lou on 7/12/25.
//

import SwiftUI
import SwiftData
import Drops

struct TunnelForwardDetailView: View {
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
    @State private var instance0LoadingState: LoadingState = .loading
    @State private var instance1LoadingState: LoadingState = .loading
    @State private var isShowEditInstance0Sheet: Bool = false
    @State private var isShowEditInstance1Sheet: Bool = false
    
    @State private var isShowErrorAlert: Bool = false
    @State private var errorMessage: String = ""
    
    enum LoadingState {
        case loading
        case loaded
        case notFound
    }
    
    var body: some View {
        if service.type == .tunnelForward {
            Form {
                Section("Relay Server") {
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
                        
                        switch instance0LoadingState {
                        case .loading:
                            ProgressView()
                                .listRowSeparator(.hidden)
                                .frame(maxWidth: .infinity)
                        case .loaded:
                            if let instance0 {
                                VStack {
                                    InstanceCardView(instance: instance0)
                                        .onTapGesture {
                                            isShowEditInstance0Sheet = true
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
                
                Section("Destination Server") {
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
                        
                        switch instance1LoadingState {
                        case .loading:
                            ProgressView()
                                .listRowSeparator(.hidden)
                                .frame(maxWidth: .infinity)
                        case .loaded:
                            if let instance1 {
                                VStack {
                                    InstanceCardView(instance: instance1)
                                        .onTapGesture {
                                            isShowEditInstance1Sheet = true
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
            instance0LoadingState = .loading
            Task {
                let instanceService = InstanceService()
                do {
                    let instances = try await instanceService.listInstances(baseURLString: server0.url, apiKey: server0.key)
                    if let foundInstance = instances.first(where: { $0.id == implementation0.instanceID }) {
                        await MainActor.run {
                            self.instance0 = foundInstance
                            self.instance0LoadingState = .loaded
                        }
                    } else {
                        await MainActor.run {
                            self.instance0 = nil
                            self.instance0LoadingState = .notFound
                        }
                    }
                }
                catch {
#if DEBUG
                    print("Error Fetching Instance 0: \(error.localizedDescription)")
#endif
                    await MainActor.run {
                        self.instance0LoadingState = .notFound
                    }
                }
            }
        }
        if let server1 {
            instance1LoadingState = .loading
            Task {
                let instanceService = InstanceService()
                do {
                    let instances = try await instanceService.listInstances(baseURLString: server1.url, apiKey: server1.key)
                    if let foundInstance = instances.first(where: { $0.id == implementation1.instanceID }) {
                        await MainActor.run {
                            self.instance1 = foundInstance
                            self.instance1LoadingState = .loaded
                        }
                    } else {
                        await MainActor.run {
                            self.instance1 = nil
                            self.instance1LoadingState = .notFound
                        }
                    }
                }
                catch {
#if DEBUG
                    print("Error Fetching Instance 1: \(error.localizedDescription)")
#endif
                    await MainActor.run {
                        self.instance1LoadingState = .notFound
                    }
                }
            }
        }
    }
}
