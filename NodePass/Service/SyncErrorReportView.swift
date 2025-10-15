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
    
    @Query private var servers: [Server]
    
    @Binding var syncErrorStore: Dictionary<String, String>
    
    var body: some View {
        NavigationStack {
            List {
                Text("\(syncErrorStore.count) error(s)")
                    .bold()
                ForEach(Array(syncErrorStore), id: \.key) { entry in
                    let server = servers.first(where: { $0.id == entry.key })
                    Text("\(server?.name ?? entry.key): \(entry.value)")
                }
            }
            .listStyle(.plain)
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
}
