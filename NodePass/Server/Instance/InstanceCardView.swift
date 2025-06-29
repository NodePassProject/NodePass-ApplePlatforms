//
//  InstanceCardView.swift
//  NodePass
//
//  Created by Junhui Lou on 7/4/25.
//

import SwiftUI

struct InstanceCardView: View {
    let instance: Instance
    
    @State private var widthForTCPAndUDPText: CGFloat?
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                switch(instance.status) {
                case .running:
                    Badge("Running", backgroundColor: .green, textColor: .white)
                case .stopped:
                    Badge("Stopped", backgroundColor: .yellow, textColor: .white)
                case .error:
                    Badge("Stopped", backgroundColor: .red, textColor: .white)
                default:
                    Badge("Unknown")
                }
                Spacer()
            }
            
            Text(instance.url)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            
            HStack {
                Text("TCP")
                    .modifier(EqualWidthModifier(width: $widthForTCPAndUDPText))
                Text("↓ \(NPCore.formatBytes(instance.tcpReceive)) ↑ \(NPCore.formatBytes(instance.tcpTransmit))")
                    .foregroundStyle(.gray)
            }
            .font(.caption)
            
            HStack {
                Text("UDP")
                    .modifier(EqualWidthModifier(width: $widthForTCPAndUDPText))
                Text("↓ \(NPCore.formatBytes(instance.udpReceive)) ↑ \(NPCore.formatBytes(instance.udpTransmit))")
                    .foregroundStyle(.gray)
            }
            .font(.caption)
        }
    }
}
