//
//  InstanceListView.swift
//  NodePass
//
//  Created by Junhui Lou on 6/30/25.
//

import SwiftUI

struct InstanceListView: View {
    @State private var loadingState: LoadingState = .idle
    
    var server: Server
    @State var instances: [Instance] = []
    
    @State private var isShowDeleteInstanceAlert: Bool = false
    @State private var instanceToDelete: Instance?
    
    @State private var isShowErrorAlert: Bool = false
    @State private var errorMessage: String = ""
    
    var body: some View {
        Form {
            ForEach(instances.filter({ [.running, .stopped, .error].contains($0.status) })) { instance in
                instanceCardView(instance: instance)
            }
        }
        .formStyle(.grouped)
#if os(iOS)
        .listRowSpacing(5)
#endif
        .navigationTitle("\(server.name!)'s Instances")
        .loadingState(loadingState: loadingState) {
            loadingState = .loading
            listInstances()
        }
        .onAppear {
            loadingState = .loading
            listInstances()
        }
        .alert("Delete Instance", isPresented: $isShowDeleteInstanceAlert) {
            Button("Delete", role: .destructive) {
                deleteInstance(instance: instanceToDelete!)
                instanceToDelete = nil
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You are about to delete this service. This action is irreversible. Are you sure?")
        }
        .alert("Error", isPresented: $isShowErrorAlert) {
            Button("OK", role: .cancel) {
                listInstances()
            }
        } message: {
            Text(errorMessage)
        }
    }
    
    @ViewBuilder
    private func instanceCardView(instance: Instance) -> some View {
        InstanceCardView(instance: instance)
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) {
                    instanceToDelete = instance
                    isShowDeleteInstanceAlert = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
            .contextMenu {
#if os(iOS)
                ControlGroup {
                    Button {
                        updateInstanceStatus(instance: instance, action: .start)
                    } label: {
                        Label("Start", systemImage: "play")
                    }
                    Button {
                        updateInstanceStatus(instance: instance, action: .stop)
                    } label: {
                        Label("Stop", systemImage: "stop")
                    }
                    Button {
                        updateInstanceStatus(instance: instance, action: .restart)
                    } label: {
                        Label("Restart", systemImage: "restart")
                    }
                }
#endif
#if os(macOS)
                ControlGroup("Actions") {
                    Button {
                        updateInstanceStatus(instance: instance, action: .start)
                    } label: {
                        Label("Start", systemImage: "play")
                    }
                    Button {
                        updateInstanceStatus(instance: instance, action: .stop)
                    } label: {
                        Label("Stop", systemImage: "stop")
                    }
                    Button {
                        updateInstanceStatus(instance: instance, action: .restart)
                    } label: {
                        Label("Restart", systemImage: "restart")
                    }
                }
#endif
                Divider()
                Button(role: .destructive) {
                    instanceToDelete = instance
                    isShowDeleteInstanceAlert = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
    }
    
    private func listInstances() {
        Task {
            let instanceService = InstanceService()
            do {
                let instances = try await instanceService.listInstances(baseURLString: server.url!, apiKey: server.key!)
                self.instances = instances
                loadingState = .loaded
            }
            catch {
                loadingState = .error("Error Listing Instances: \(error.localizedDescription)")
            }
        }
    }
    
    private func deleteInstance(instance: Instance) {
        Task {
            let instanceService = InstanceService()
            do {
                try await instanceService.deleteInstance(baseURLString: server.url!, apiKey: server.key!, id: instance.id)
                listInstances()
            }
            catch {
                errorMessage = "Error Deleting Instances: \(error.localizedDescription)"
                isShowErrorAlert = true
            }
        }
    }
    
    private func updateInstanceStatus(instance: Instance, action: UpdateInstanceStatusAction) {
        Task {
            let instanceService = InstanceService()
            do {
                try await instanceService.updateInstanceStatus(baseURLString: server.url!, apiKey: server.key!, id: instance.id, action: action.rawValue)
                listInstances()
            }
            catch {
                switch(action) {
                case .start:
                    errorMessage = "Error Starting Instances: \(error.localizedDescription)"
                case .stop:
                    errorMessage = "Error Stopping Instances: \(error.localizedDescription)"
                case .restart:
                    errorMessage = "Error Restarting Instances: \(error.localizedDescription)"
                }
                isShowErrorAlert = true
            }
        }
    }
}
