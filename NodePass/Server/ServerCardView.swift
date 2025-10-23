//
//  ServerCardView.swift
//  NodePass
//
//  Created by Junhui Lou on 10/23/25.
//

import SwiftUI

struct ServerCardView: View {
    @Environment(NPState.self) var state
    let server: Server
    
    var body: some View {
        let metadata = state.serverMetadatas[server.id]
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading) {
                HStack(spacing: 10) {
                    Text(server.name)
                    if let uptime = metadata?.uptime {
                        HStack(spacing: 5) {
                            Image(systemName: "power")
                            Text(NPCore.formatTimeInterval(seconds: uptime))
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
#if DEBUG
                Text(verbatim: "https://node.nodepass.eu/api/v1")
                    .font(.caption)
                    .foregroundStyle(.secondary)
#else
                Text(server.url)
                    .font(.caption)
                    .foregroundStyle(.secondary)
#endif
            }
            
            Spacer()
            
            if let metadata {
                if let cpu = metadata.cpu, let memoryUsed = metadata.memoryUsed, let memoryTotal = metadata.memoryTotal, let swapUsed = metadata.swapUsed, let swapTotal = metadata.swapTotal, let networkReceive = metadata.networkReceive, let networkTransmit = metadata.networkTransmit {
                    HStack(alignment: .top) {
                        Gauge(value: Double(cpu), in: 0...100) {
                            Text("CPU")
                                .font(.system(.caption, design: .rounded))
                                .bold()
                        }
                        .gaugeStyle(SingleMatrixGaugeStyle(color: .blue, size: 50))
                        Spacer()
                        Gauge(value: Double(memoryUsed) / Double(memoryTotal), in: 0...1) {
                            Text("Memory")
                                .font(.system(.caption, design: .rounded))
                                .bold()
                        }
                        .gaugeStyle(SingleMatrixGaugeStyle(color: .blue, size: 50))
                        Spacer()
                        let swapPercentage = swapTotal == 0 ? 0 : Double(swapUsed) / Double(swapTotal)
                        Gauge(value: swapPercentage, in: 0...1) {
                            Text("Swap")
                                .font(.system(.caption, design: .rounded))
                                .bold()
                        }
                        .gaugeStyle(SingleMatrixGaugeStyle(color: .blue, size: 50))
                        Spacer()
                        VStack {
                            let networkReceiveDouble: Double = Double(networkReceive)
                            let networkTransmitDouble: Double = Double(networkTransmit)
                            let networkTotalDouble: Double = networkReceiveDouble + networkTransmitDouble
                            Gauge(value: networkReceiveDouble / networkTotalDouble, in: 0...1) {
                                Text("Network")
                                    .font(.system(.caption, design: .rounded))
                                    .bold()
                            }
                            .gaugeStyle(
                                DoubleMatrixGaugeStyle(
                                    text1: "↑ \(NPCore.formatBytes(networkTransmit, decimals: 0))",
                                    text2: "↓ \(NPCore.formatBytes(networkReceive, decimals: 0))",
                                    color1: .cyan,
                                    color2: .orange,
                                    size: 50
                                )
                            )
                        }
                    }
                }
                else {
                    Text("Matrix Unavailable")
                        .bold()
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
                
                Spacer()
                
                HStack {
                    Text(metadata.os)
                    Text(metadata.architecture)
                    Text(metadata.version)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            else {
                Text("Metadata Unavailable")
                    .bold()
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                Spacer()
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .foregroundStyle(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.08), radius: 5, x: 5, y: 5)
                .shadow(color: .black.opacity(0.06), radius: 5, x: -5, y: -5)
        )
    }
}
