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
                    Badge("Error", backgroundColor: .red, textColor: .white)
                case .other(let status):
                    Badge(status)
                }
                if let ping = instance.ping {
                    Badge("\(ping) ms", backgroundColor: .blue, textColor: .white)
                }
                Spacer()
            }
            
            Text(instance.url)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            
            HStack {
                Text("TCP")
                    .bold()
                    .modifier(EqualWidthModifier(width: $widthForSubtitleText, alignment: .leading))
                if let tcp = instance.tcp {
                    Text("\(String(tcp))")
                        .foregroundStyle(.secondary)
                        .modifier(EqualWidthModifier(width: $widthForConnectionCountContent, alignment: .leading))
                }
                HStack(spacing: 3) {
                    Text("↓")
                    Text("\(NPCore.formatBytes(instance.tcpReceive))")
                        .foregroundStyle(.secondary)
                }
                .modifier(EqualWidthModifier(width: $widthForRXTitleAndContent, alignment: .leading))
                HStack(spacing: 3) {
                    Text("↑")
                    Text("\(NPCore.formatBytes(instance.tcpTransmit))")
                        .foregroundStyle(.secondary)
                }
                .modifier(EqualWidthModifier(width: $widthForTXTitleAndContent, alignment: .leading))
            }
            .font(.caption)
            
            HStack {
                Text("UDP")
                    .bold()
                    .modifier(EqualWidthModifier(width: $widthForSubtitleText, alignment: .leading))
                if let udp = instance.udp {
                    Text("\(String(udp))")
                        .foregroundStyle(.secondary)
                        .modifier(EqualWidthModifier(width: $widthForConnectionCountContent, alignment: .leading))
                }
                HStack(spacing: 3) {
                    Text("↓")
                    Text("\(NPCore.formatBytes(instance.udpReceive))")
                        .foregroundStyle(.secondary)
                }
                .modifier(EqualWidthModifier(width: $widthForRXTitleAndContent, alignment: .leading))
                HStack(spacing: 3) {
                    Text("↑")
                    Text("\(NPCore.formatBytes(instance.udpTransmit))")
                        .foregroundStyle(.secondary)
                }
                .modifier(EqualWidthModifier(width: $widthForTXTitleAndContent, alignment: .leading))
            }
            .font(.caption)
            
            if let poolConnectionCount = instance.poolConnectionCount {
                HStack {
                    Text("Pool")
                        .bold()
                        .modifier(EqualWidthModifier(width: $widthForSubtitleText, alignment: .leading))
                    Text(String(poolConnectionCount))
                        .foregroundStyle(.secondary)
                        .modifier(EqualWidthModifier(width: $widthForConnectionCountContent, alignment: .leading))
                }
                .font(.caption)
            }
        }
    }
}
