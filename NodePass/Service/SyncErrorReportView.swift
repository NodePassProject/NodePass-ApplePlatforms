//
//  SyncErrorReportView.swift
//  NodePass
//
//  Created by Junhui Lou on 10/15/25.
//

import SwiftUI
import SwiftData

struct SyncErrorReportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    
    @Query private var servers: [Server]
    
    @Binding var syncErrorStore: Dictionary<String, String>
    
    private var enabledServers: [Server] {
        servers.filter { $0.isEnabled }
    }
    
    private var errorServers: [Server] {
        syncErrorStore.keys.compactMap { serverId in
            servers.first(where: { $0.id == serverId })
        }
    }
    
    private var hasEnabledErrorServers: Bool {
        errorServers.contains { $0.isEnabled }
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("\(syncErrorStore.count) \(syncErrorStore.count == 1 ? "error" : "errors")")
                        .bold()
                    
                    if !errorServers.isEmpty {
                        Button {
                            disableAllErrorServers()
                        } label: {
                            Label("Disable Error \(syncErrorStore.count == 1 ? "Server" : "Servers")", systemImage: "pause.circle.fill")
                        }
                        .disabled(!hasEnabledErrorServers)
                    }
                }
                
                Section {
                    ForEach(Array(syncErrorStore), id: \.key) { entry in
                        if let server = servers.first(where: { $0.id == entry.key }) {
                            HStack(alignment: .center, spacing: 12) {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Circle()
                                            .fill(server.isEnabled ? Color.green : Color.gray)
                                            .frame(width: 8, height: 8)
                                        Text(server.name)
                                            .font(.headline)
                                    }
                                    
                                    Text(entry.value)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                                
                                Button {
                                    server.isEnabled.toggle()
                                    try? context.save()
                                } label: {
                                    Image(systemName: server.isEnabled ? "pause.circle.fill" : "play.circle.fill")
                                        .font(.title3)
                                }
                                .buttonStyle(.borderless)
                            }
                            .padding(.vertical, 4)
                        } else {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.key)
                                    .font(.headline)
                                Text(entry.value)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                } header: {
                    Text("Error Details")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Sync Error Report")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    if #available(iOS 26.0, macOS 26.0, *) {
                        Button(role: .confirm) {
                            dismiss()
                        } label: {
                            Label("Done", systemImage: "checkmark")
                        }
                    }
                    else {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
            }
        }
    }
    
    private func disableAllErrorServers() {
        for server in errorServers where server.isEnabled {
            server.isEnabled = false
        }
        try? context.save()
    }
}
