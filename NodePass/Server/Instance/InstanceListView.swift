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
    
    @State private var isShowAddInstanceAlert: Bool = false
    @State private var commandOfNewInstance: String = ""
    
    @State private var isShowEditInstanceAlert: Bool = false
    @State private var commandOfEditedInstance: String = ""
    @State private var instanceToEdit: Instance?
    
    @State private var isShowDeleteInstanceAlert: Bool = false
    @State private var instanceToDelete: Instance?
    
    @State private var isShowErrorAlert: Bool = false
    @State private var errorMessage: String = ""
    
    var body: some View {
        Form {
            let validInstances = instances.filter({ [.running, .stopped, .error].contains($0.status) })
            ForEach(validInstances) { instance in
                instanceCard(instance: instance)
            }
            .animation(.default, value: validInstances)
        }
        .formStyle(.grouped)
#if os(iOS)
        .listRowSpacing(5)
#endif
        .navigationTitle(server.name)
        .toolbar {
            ToolbarItem {
                Button {
                    isShowAddInstanceAlert = true
                } label: {
                    Label("Add Instance", systemImage: "plus")
                }
            }
        }
        .loadingState(loadingState: loadingState) {
            loadingState = .loading
            listInstances()
        }
        .onAppear {
            loadingState = .loading
            listInstances()
        }
        .alert("Add Instance", isPresented: $isShowAddInstanceAlert) {
            TextField("URL", text: $commandOfNewInstance)
            Button("Add") {
                addInstance()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enter URL for the new instance.")
        }
        .alert("Edit Instance", isPresented: $isShowEditInstanceAlert) {
            TextField("URL", text: $commandOfEditedInstance)
            Button("OK") {
                updateInstance(instance: instanceToEdit!)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enter a new URL for this instance.")
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
    private func instanceCard(instance: Instance) -> some View {
        InstanceCardView(instance: instance)
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
                Button {
                    NPUI.copyToClipboard(instance.url)
                } label: {
                    Label("Copy URL", systemImage: "document.on.document")
                }
                Button {
                    instanceToEdit = instance
                    commandOfEditedInstance = instance.url
                    isShowEditInstanceAlert = true
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
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
                let instances = try await instanceService.listInstances(baseURLString: server.url, apiKey: server.key)
                self.instances = instances
                loadingState = .loaded
            }
            catch {
                loadingState = .error("Error Listing Instances: \(error.localizedDescription)")
            }
        }
    }
    
    private func addInstance() {
        Task {
            let instanceService = InstanceService()
            do {
                _ = try await instanceService.createInstance(
                    baseURLString: server.url,
                    apiKey: server.key,
                    url: commandOfNewInstance
                )
                listInstances()
            } catch {
                errorMessage = String(localized: "Error Creating Instances: \(error.localizedDescription)")
                isShowErrorAlert = true
            }
        }
    }
    
    private func deleteInstance(instance: Instance) {
        Task {
            let instanceService = InstanceService()
            do {
                try await instanceService.deleteInstance(baseURLString: server.url, apiKey: server.key, id: instance.id)
                listInstances()
            }
            catch {
                errorMessage = String(localized: "Error Deleting Instances: \(error.localizedDescription)")
                isShowErrorAlert = true
            }
        }
    }
    
    private func updateInstance(instance: Instance) {
        Task {
            let instanceService = InstanceService()
            do {
                _ = try await instanceService.updateInstance(baseURLString: server.url, apiKey: server.key, id: instance.id, url: commandOfEditedInstance)
                listInstances()
            }
            catch {
                errorMessage = String(localized: "Error Updating Instances: \(error.localizedDescription)")
                isShowErrorAlert = true
            }
        }
    }
    
    private func updateInstanceStatus(instance: Instance, action: UpdateInstanceStatusAction) {
        Task {
            let instanceService = InstanceService()
            do {
                try await instanceService.updateInstanceStatus(baseURLString: server.url, apiKey: server.key, id: instance.id, action: action.rawValue)
                listInstances()
            }
            catch {
                switch(action) {
                case .start:
                    errorMessage = String(localized: "Error Starting Instances: \(error.localizedDescription)")
                case .stop:
                    errorMessage = String(localized: "Error Stopping Instances: \(error.localizedDescription)")
                case .restart:
                    errorMessage = String(localized: "Error Restarting Instances: \(error.localizedDescription)")
                }
                isShowErrorAlert = true
            }
        }
    }
}
