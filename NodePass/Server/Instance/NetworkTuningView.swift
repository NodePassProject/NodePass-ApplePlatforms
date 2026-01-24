//
//  NetworkTuningView.swift
//  NodePass
//
//  Created by Yosebyte on 1/24/26.
//

import SwiftUI

struct NetworkTuningView: View {
    @Binding var dnsCache: String
    @Binding var dialAddress: String
    @Binding var readTimeout: String
    @Binding var rateLimit: String
    @Binding var maxSlots: String
    
    var body: some View {
        Form {
            Section {
                LabeledTextField("DNS Cache Duration", prompt: "5m", text: $dnsCache)
                    .autocorrectionDisabled()
#if os(iOS)
                    .textInputAutocapitalization(.never)
#endif
                
                LabeledTextField("Dial Address", prompt: "auto", text: $dialAddress)
                    .autocorrectionDisabled()
#if os(iOS)
                    .textInputAutocapitalization(.never)
#endif
                
                LabeledTextField("Read Timeout", prompt: "0", text: $readTimeout)
                    .autocorrectionDisabled()
#if os(iOS)
                    .textInputAutocapitalization(.never)
#endif
                
                LabeledTextField("Rate Limit (Mbps)", prompt: "0", text: $rateLimit, isNumberOnly: true)
                
                LabeledTextField("Max Connections", prompt: "65536", text: $maxSlots, isNumberOnly: true)
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("DNS: Cache TTL duration in '30s, 5m, 1h'.")
                        .foregroundStyle(.secondary)
                    Text("Dial: Specific source IP or 'auto' by OS.")
                        .foregroundStyle(.secondary)
                    Text("Read: Timeout duration or 0 to disable.")
                        .foregroundStyle(.secondary)
                    Text("Rate: Bandwidth limit or 0 for unlimited.")
                        .foregroundStyle(.secondary)
                    Text("Slot: Max concurrent connections allowed.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Network Tuning")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
    }
}
