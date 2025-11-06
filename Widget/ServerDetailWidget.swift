//
//  ServerDetailWidget.swift
//  NodePass
//
//  Created by Junhui Lou on 9/22/25.
//

import WidgetKit
import SwiftUI
import AppIntents

struct ServerDetailProvider: AppIntentTimelineProvider {
    typealias Entry = ServerEntry
    
    typealias Intent = ServerDetailConfigurationIntent
    
    let demoServer = ServerEntry(
        date: Date(),
        data:
            ServerEntry.ServerData(
                id: "demo-server",
                name: "Demo",
                metadata: ServerMetadata(
                    os: "linux",
                    architecture: "amd64",
                    cpu: 30,
                    memoryUsed: 1610612736,
                    memoryTotal: 2147483648,
                    swapUsed: 402653184,
                    swapTotal: 1073741824,
                    networkReceive: 107374182400,
                    networkTransmit: 107374182400,
                    systemUptime: 432000,
                    version: "1.7.0",
                    name: "Demo",
                    uptime: 432000,
                    logLevel: "warn",
                    tlsLevel: "1"
                )
            ),
        message: "Placeholder"
    )
    
    func placeholder(in context: Context) -> ServerEntry {
        return demoServer
    }
    
    func snapshot(for configuration: ServerDetailConfigurationIntent, in context: Context) async -> ServerEntry {
        let entry = await getServerEntry(server: configuration.server)
        return entry
    }
    
    func timeline(for configuration: ServerDetailConfigurationIntent, in context: Context) async -> Timeline<ServerEntry> {
        let entry = await getServerEntry(server: configuration.server)
        return Timeline(entries: [entry], policy: .atEnd)
    }
    
    func getServerEntry(server: ServerEntity?) async -> ServerEntry {
        guard let server else {
            return demoServer
        }
        do {
            let serverService = ServerService()
            let metadata = try await serverService.getServerInfo(baseURLString: server.url, apiKey: server.key)
            
            return ServerEntry(date: Date(), data: ServerEntry.ServerData(id: server.id, name: server.name, metadata: metadata), message: "OK")
        }
        catch {
#if DEBUG
            print("Error Getting Server Entry: \(error.localizedDescription)")
#endif
            return ServerEntry(date: Date(), data: nil, message: error.localizedDescription)
        }
    }
}

struct ServerDetailWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: ServerDetailProvider.Entry
    
    var body: some View {
        Group {
            if let data = entry.data {
                Group {
                    switch(family) {
                    case .systemSmall:
                        systemSmallView(data: data)
                    case .systemMedium:
                        systemMediumView(date: entry.date, data: data)
                    default:
                        Text("Unsupported family")
                    }
                }
                .widgetURL(URL(string: "np://server?id=\(data.id)"))
            }
            else {
                VStack(spacing: 10) {
                    Text(entry.message)
                    Button(intent: RefreshWidgetIntent()) {
                        Text("Retry")
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        .containerBackground(.background, for: .widget)
    }
    
    @ViewBuilder
    func systemSmallView(data: ServerEntry.ServerData) -> some View {
        let metadata = data.metadata
        VStack {
            if let cpu = metadata.cpu, let memoryUsed = metadata.memoryUsed, let memoryTotal = metadata.memoryTotal, let swapUsed = metadata.swapUsed, let swapTotal = metadata.swapTotal, let networkReceive = metadata.networkReceive, let networkTransmit = metadata.networkTransmit {
                HStack(spacing: 10) {
                    Gauge(value: Double(cpu), in: 0...100) {
                        Text("CPU")
                            .font(.system(.caption, design: .rounded))
                            .bold()
                    }
                    .gaugeStyle(SingleMatrixGaugeStyle(color: .blue, size: 40))
                    Spacer()
                    Gauge(value: Double(memoryUsed) / Double(memoryTotal), in: 0...1) {
                        Text("Memory")
                            .font(.system(.caption, design: .rounded))
                            .bold()
                    }
                    .gaugeStyle(SingleMatrixGaugeStyle(color: .blue, size: 40))
                }
                Spacer()
                HStack(spacing: 10) {
                    let swapPercentage = swapTotal == 0 ? 0 : Double(swapUsed) / Double(swapTotal)
                    Gauge(value: swapPercentage, in: 0...1) {
                        Text("Swap")
                            .font(.system(.caption, design: .rounded))
                            .bold()
                    }
                    .gaugeStyle(SingleMatrixGaugeStyle(color: .blue, size: 40))
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
                                size: 40
                            )
                        )
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    func systemMediumView(date: Date, data: ServerEntry.ServerData) -> some View {
        let metadata = data.metadata
        VStack(alignment: .leading) {
            HStack {
                HStack(spacing: 10) {
                    Text(data.name)
                    if let uptime = metadata.uptime {
                        HStack(spacing: 5) {
                            Image(systemName: "power")
                            Text(NPCore.formatTimeInterval(seconds: uptime))
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button(intent: RefreshWidgetIntent()) {
                    Text(date, style: .time)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(PlainButtonStyle())
            }
            .lineLimit(1)
            .font(.subheadline)
            
            Spacer()
            
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
            
            Spacer()
        }
    }
}

struct ServerEntry: TimelineEntry {
    struct ServerData {
        let id: String
        let name: String
        let metadata: ServerMetadata
    }
    let date: Date
    let data: ServerData?
    let message: String
}

struct ServerDetailWidget: Widget {
    let kind: String = "ServerDetailWidget"
    
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ServerDetailConfigurationIntent.self, provider: ServerDetailProvider()) { entry in
            ServerDetailWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Server Details")
        .description("View details of your servers at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
