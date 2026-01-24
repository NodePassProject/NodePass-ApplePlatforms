//
//  TrafficBlockingView.swift
//  NodePass
//
//  Created by Junhui Lou on 1/24/26.
//

import SwiftUI

struct TrafficBlockingView: View {
    @Binding var blockHTTP: Bool
    @Binding var blockTLS: Bool
    @Binding var blockSOCKS: Bool
    
    var body: some View {
        Form {
            Section {
                Toggle("Block HTTP", isOn: $blockHTTP)
                Toggle("Block TLS", isOn: $blockTLS)
                Toggle("Block SOCKS", isOn: $blockSOCKS)
            } footer: {
                Text("Block certain traffic from being tunneled")
            }
        }
        .navigationTitle("Traffic Blocking")
    }
}
