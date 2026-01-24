//
//  ProtocolControlView.swift
//  NodePass
//
//  Created by Yosebyte on 1/24/26.
//

import SwiftUI

struct ProtocolControlView: View {
    @Binding var disableTCP: Bool
    @Binding var disableUDP: Bool
    @Binding var enableProxy: Bool
    
    var body: some View {
        Form {
            Section {
                Toggle("Disable TCP", isOn: $disableTCP)
                Toggle("Disable UDP", isOn: $disableUDP)
                Toggle("Enable PROXY Protocol", isOn: $enableProxy)
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Control protocol availability and PROXY v1 support.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Protocol Control")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
    }
}
