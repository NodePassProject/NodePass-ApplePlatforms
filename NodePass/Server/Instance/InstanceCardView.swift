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
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            
            HStack {
                Text("TCP")
                    .bold()
                if let tcp = instance.tcp {
                    HStack(spacing: 3) {
                        Text(String(localized: "Count", comment: "Connection Count"))
                        Text("\(String(tcp))")
                            .foregroundStyle(.secondary)
                    }
                }
                HStack(spacing: 3) {
                    Text("RX")
                    Text("\(NPCore.formatBytes(instance.tcpReceive))")
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 3) {
                    Text("TX")
                    Text("\(NPCore.formatBytes(instance.tcpTransmit))")
                        .foregroundStyle(.secondary)
                }
            }
            .font(.caption)
            
            HStack {
                Text("UDP")
                    .bold()
                if let udp = instance.udp {
                    HStack(spacing: 3) {
                        Text(String(localized: "Count", comment: "Connection Count"))
                        Text("\(String(udp))")
                            .foregroundStyle(.secondary)
                    }
                }
                HStack(spacing: 3) {
                    Text("RX")
                    Text("\(NPCore.formatBytes(instance.udpReceive))")
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 3) {
                    Text("TX")
                    Text("\(NPCore.formatBytes(instance.udpTransmit))")
                        .foregroundStyle(.secondary)
                }
            }
            .font(.caption)
            
            if let poolConnectionCount = instance.poolConnectionCount {
                HStack {
                    Text("Pool")
                        .bold()
                    Text(String(poolConnectionCount))
                        .foregroundStyle(.secondary)
                }
                .font(.caption)
            }
        }
#if os(macOS)
        .background(.white.opacity(0.01))
#endif
    }
}
