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
    
    @State private var isShowErrorAlert: Bool = false
    @State private var errorMessage: String = ""
    
    var body: some View {
        List {
            ForEach(instances.filter({ [.running, .stopped, .error].contains($0.status) })) { instance in
                InstanceCardView(instance: instance)
                    .swipeActions(edge: .trailing) {
                        Button("Delete", role: .destructive) {
                            deleteInstance(instance: instance)
                        }
                    }
                    .contextMenu {
                        Button(role: .destructive) {
                            deleteInstance(instance: instance)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
        .navigationTitle(server.name!)
        .loadingState(loadingState: loadingState) {
            listInstances()
        }
        .onAppear {
            listInstances()
        }
        .alert("Error", isPresented: $isShowErrorAlert) {
            Button("OK", role: .cancel) {
                listInstances()
            }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func listInstances() {
        loadingState = .loading
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
                
                do {
                    let instances = try await instanceService.listInstances(baseURLString: server.url!, apiKey: server.key!)
                    self.instances = instances
                }
                catch {
                    loadingState = .error("Error Listing Instances: \(error.localizedDescription)")
                }
            }
            catch {
                errorMessage = "Error Deleting Instances: \(error.localizedDescription)"
                isShowErrorAlert = true
            }
        }
    }
}
