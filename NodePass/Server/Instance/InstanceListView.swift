//
//  InstanceListView.swift
//  NodePass
//
//  Created by Junhui Lou on 6/30/25.
//

import SwiftUI

struct InstanceListView: View {
    @State private var loadingState: LoadingState = .idle
    @State private var searchText: String = ""
    
    var server: Server
    @State var instances: [Instance] = []
    
    @State private var isShowAddInstanceSheet: Bool = false
    @State private var instanceToEdit: Instance?
    
    @State private var isShowDeleteInstanceAlert: Bool = false
    @State private var instanceToDelete: Instance?
    
    @State private var isShowErrorAlert: Bool = false
    @State private var errorMessage: String = ""
    
    var body: some View {
        Form {
            let validInstances = instances.filter({ [.running, .stopped, .error].contains($0.status) })
            let filteredInstances = validInstances.filter { instance in
                searchText.isEmpty || instance.url.localizedCaseInsensitiveContains(searchText)
            }
            ForEach(filteredInstances) { instance in
                instanceCard(instance: instance)
            }
            .animation(.default, value: filteredInstances)
        }
        .formStyle(.grouped)
#if os(iOS)
        .listRowSpacing(5)
#endif
        .navigationTitle(server.name)
        .searchable(text: $searchText, placement: .toolbar)
        .toolbar {
            ToolbarItem {
                Button {
                    isShowAddInstanceSheet = true
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
        .sheet(isPresented: $isShowAddInstanceSheet) {
            AddInstanceView(server: server) {
                listInstances()
            }
        }
        .sheet(item: $instanceToEdit) { instance in
            EditInstanceView(server: server, instance: instance) {
                listInstances()
            }
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
            .swipeActions(edge: .leading) {
                Button {
                    NPUI.copyToClipboard(instance.url)
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .tint(.blue)
            }
            .swipeActions(edge: .trailing) {
                Button {
                    instanceToEdit = instance
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                .tint(.orange)
            }
            .contextMenu {
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
#if DEBUG
                print("Error Listing Instances: \(error.localizedDescription)")
                loadingState = .error(error.localizedDescription)
#endif
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
#if DEBUG
                print("Error Deleting Instances: \(error.localizedDescription)")
                loadingState = .error(error.localizedDescription)
#endif
                errorMessage = error.localizedDescription
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
#if DEBUG
                    print("Error Starting Instances: \(error.localizedDescription)")
                    loadingState = .error(error.localizedDescription)
#endif
                    errorMessage = error.localizedDescription
                case .stop:
#if DEBUG
                    print("Error Stopping Instances: \(error.localizedDescription)")
                    loadingState = .error(error.localizedDescription)
#endif
                    errorMessage = error.localizedDescription
                case .restart:
#if DEBUG
                    print("Error Restarting Instances: \(error.localizedDescription)")
                    loadingState = .error(error.localizedDescription)
#endif
                    errorMessage = error.localizedDescription
                }
                isShowErrorAlert = true
            }
        }
    }
}
