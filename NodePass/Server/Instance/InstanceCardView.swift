//
//  InstanceCardView.swift
//  NodePass
//
//  Created by Junhui Lou on 7/4/25.
//

import SwiftUI

struct InstanceCardView: View {
    let instance: Instance
    
    @State private var widthForSubtitleText: CGFloat?
    @State private var widthForConnectionCountContent: CGFloat?
    @State private var widthForRXTitleAndContent: CGFloat?
    @State private var widthForTXTitleAndContent: CGFloat?
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack(spacing: 4) {
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
                if let ping = instance.ping {
                    Badge("\(ping) ms", backgroundColor: .blue, textColor: .white)
                }
                Spacer()
            }
            
            Text(instance.url)
                .font(.system(size: 16))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            
            HStack {
                Text("TCP")
                    .bold()
                    .modifier(EqualWidthModifier(width: $widthForSubtitleText))
                if let tcp = instance.tcp {
                    Text("\(String(tcp))")
                        .foregroundStyle(.secondary)
                        .modifier(EqualWidthModifier(width: $widthForConnectionCountContent))
                }
                HStack(spacing: 3) {
                    Text("↓")
                    Text("\(NPCore.formatBytes(instance.tcpReceive))")
                        .foregroundStyle(.secondary)
                }
                .modifier(EqualWidthModifier(width: $widthForRXTitleAndContent))
                HStack(spacing: 3) {
                    Text("↑")
                    Text("\(NPCore.formatBytes(instance.tcpTransmit))")
                        .foregroundStyle(.secondary)
                }
                .modifier(EqualWidthModifier(width: $widthForTXTitleAndContent))
            }
            .font(.caption)
            
            HStack {
                Text("UDP")
                    .bold()
                    .modifier(EqualWidthModifier(width: $widthForSubtitleText))
                if let udp = instance.udp {
                    Text("\(String(udp))")
                        .foregroundStyle(.secondary)
                        .modifier(EqualWidthModifier(width: $widthForConnectionCountContent))
                }
                HStack(spacing: 3) {
                    Text("↓")
                    Text("\(NPCore.formatBytes(instance.udpReceive))")
                        .foregroundStyle(.secondary)
                }
                .modifier(EqualWidthModifier(width: $widthForRXTitleAndContent))
                HStack(spacing: 3) {
                    Text("↑")
                    Text("\(NPCore.formatBytes(instance.udpTransmit))")
                        .foregroundStyle(.secondary)
                }
                .modifier(EqualWidthModifier(width: $widthForTXTitleAndContent))
            }
            .font(.caption)
            
            if let poolConnectionCount = instance.poolConnectionCount {
                HStack {
                    Text("Pool")
                        .bold()
                        .modifier(EqualWidthModifier(width: $widthForSubtitleText))
                    Text(String(poolConnectionCount))
                        .foregroundStyle(.secondary)
                        .modifier(EqualWidthModifier(width: $widthForConnectionCountContent))
                }
                .font(.caption)
            }
        }
#if os(macOS)
        .background(.white.opacity(0.01))
#endif
    }
}
