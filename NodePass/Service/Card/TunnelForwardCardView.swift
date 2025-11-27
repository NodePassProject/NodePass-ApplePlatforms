//
//  TunnelForwardCardView.swift
//  NodePass
//
//  Created by Junhui Lou on 7/4/25.
//

import SwiftUI
import SwiftData

struct TunnelForwardCardView: View {
    let service: Service
    var isPreview: Bool = false
    
    @Query private var servers: [Server]
    
    @State private var heightForMainImages: CGFloat?
    
    var implementation0: Implementation {
        service.implementations!.first(where: { $0.position == 0 })!
    }
    var addressesAndPorts0: (tunnel: (address: String, port: String), destination: (address: String, port: String)) {
        NPCore.parseAddressesAndPorts(urlString: implementation0.command)
    }
    var implementation1: Implementation {
        service.implementations!.first(where: { $0.position == 1 })!
    }
    var addressesAndPorts1: (tunnel: (address: String, port: String), destination: (address: String, port: String)) {
        NPCore.parseAddressesAndPorts(urlString: implementation1.command)
    }
    
    var body: some View {
        if service.type == .tunnelForward {
            cardContent
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .foregroundStyle(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.08), radius: 5, x: 5, y: 5)
                        .shadow(color: .black.opacity(0.06), radius: 5, x: -5, y: -5)
                )
        }
        else {
            Image(systemName: "exclamationmark.circle")
                .foregroundStyle(.red)
        }
    }
    
    private var cardContent: some View {
        VStack(spacing: 20) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Tunnel Forward")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                        .bold()
                    Text(service.name)
                }
                Spacer()
            }
            
            HStack(alignment: .imageAlignment) {
                Image(systemName: "laptopcomputer.and.iphone")
                    .font(.title)
                    .modifier(EqualHeightModifier(height: $heightForMainImages, alignment: .center))
                    .alignmentGuide(.imageAlignment) { d in d[VerticalAlignment.center] }
                Spacer()
                Image(systemName: "arrowshape.right")
                    .alignmentGuide(.imageAlignment) { d in d[VerticalAlignment.center] }
                Spacer()
                VStack(spacing: 3) {
                    let serverName = servers.first(where: { $0.id == implementation0.serverID })?.name ?? String(localized: isPreview ? "Select" : "Unknown")
                    let addressesAndPorts = NPCore.parseAddressesAndPorts(urlString: implementation0.command)
                    Text(serverName)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: 60)
                    Image(systemName: "airplane.cloud")
                        .font(.title)
                        .modifier(EqualHeightModifier(height: $heightForMainImages, alignment: .center))
                        .alignmentGuide(.imageAlignment) { d in d[VerticalAlignment.center] }
                    Text(addressesAndPorts.destination.port)
                        .font(.system(size: 8))
                }
                Spacer()
                VStack(spacing: 3) {
                    let queryParameters = NPCore.parseQueryParameters(urlString: implementation0.command)
                    if ["1", "2"].contains(queryParameters["tls"]) {
                        Image(systemName: "lock")
                            .font(.caption)
                    }
                    Image(systemName: "arrowshape.right")
                        .alignmentGuide(.imageAlignment) { d in d[VerticalAlignment.center] }
                }
                Spacer()
                Group {
                    let addressesAndPorts = NPCore.parseAddressesAndPorts(urlString: implementation1.command)
                    if addressesAndPorts.destination.address == "127.0.0.1" {
                        VStack(spacing: 3) {
                            let serverName = servers.first(where: { $0.id == implementation1.serverID })?.name ?? String(localized: isPreview ? "Select" : "Unknown")
                            let addressesAndPorts = NPCore.parseAddressesAndPorts(urlString: implementation1.command)
                            Text(serverName)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                                .font(.system(size: 8))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: 60)
                            Image(systemName: "airplane.arrival")
                                .font(.title)
                                .modifier(EqualHeightModifier(height: $heightForMainImages, alignment: .center))
                                .alignmentGuide(.imageAlignment) { d in d[VerticalAlignment.center] }
                            Text(addressesAndPorts.destination.port)
                                .font(.system(size: 8))
                        }
                    }
                    else {
                        VStack(spacing: 3) {
                            let serverName = servers.first(where: { $0.id == implementation1.serverID })?.name ?? String(localized: isPreview ? "Select" : "Unknown")
                            Text(serverName)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                                .font(.system(size: 8))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: 60)
                            Image(systemName: "airplane.cloud")
                                .font(.title)
                                .modifier(EqualHeightModifier(height: $heightForMainImages, alignment: .center))
                                .alignmentGuide(.imageAlignment) { d in d[VerticalAlignment.center] }
                        }
                        Spacer()
                        Image(systemName: "arrowshape.right")
                            .alignmentGuide(.imageAlignment) { d in d[VerticalAlignment.center] }
                        Spacer()
                        if implementation1.isMultipleDestination {
                            VStack(spacing: 3) {
                                Text("\(implementation1.destinationCount) Targets")
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.5)
                                    .font(.system(size: 8))
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: 60)
                                Image(systemName: "point.3.filled.connected.trianglepath.dotted")
                                    .font(.title)
                                    .modifier(EqualHeightModifier(height: $heightForMainImages, alignment: .center))
                                    .alignmentGuide(.imageAlignment) { d in d[VerticalAlignment.center] }
                            }
                        }
                        else {
                            VStack(spacing: 3) {
                                Text(addressesAndPorts.destination.address)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.5)
                                    .font(.system(size: 8))
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: 60)
                                Image(systemName: "airplane.arrival")
                                    .font(.title)
                                    .modifier(EqualHeightModifier(height: $heightForMainImages, alignment: .center))
                                    .alignmentGuide(.imageAlignment) { d in d[VerticalAlignment.center] }
                                Text(addressesAndPorts.destination.port)
                                    .font(.system(size: 8))
                            }
                        }
                    }
                }
            }
        }
        .padding()
    }
}
