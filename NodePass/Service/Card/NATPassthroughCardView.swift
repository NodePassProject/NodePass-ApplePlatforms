//
//  NATPassthroughCardView.swift
//  NodePass
//
//  Created by Junhui Lou on 7/4/25.
//

import SwiftUI
import SwiftData

struct NATPassthroughCardView: View {
    let service: Service
    var isPreview: Bool = false
    
    @Query private var servers: [Server]
    
    var body: some View {
        if service.type == .natPassthrough {
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
                    Text("NAT Passthrough")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                        .bold()
                    Text(service.name)
                }
                Spacer()
            }
            
            HStack {
                let implementation0 = service.implementations!.first(where: { $0.position == 0 })!
                let implementation1 = service.implementations!.first(where: { $0.position == 1 })!
                Image(systemName: "laptopcomputer.and.iphone")
                    .font(.title)
                Spacer()
                Image(systemName: "arrowshape.right")
                    .alignmentGuide(VerticalAlignment.center) { d in
                        d[.bottom] - 7
                    }
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
                    Image(systemName: "cloud.fill")
                        .font(.title)
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
                }
                .alignmentGuide(VerticalAlignment.center) { d in
                    d[.bottom] - 7
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
                            Image(systemName: "house.fill")
                                .font(.title)
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
                            Image(systemName: "house.fill")
                                .font(.title)
                            Text(addressesAndPorts.tunnel.port)
                                .font(.system(size: 8))
                        }
                        Spacer()
                        Image(systemName: "arrowshape.right")
                            .alignmentGuide(VerticalAlignment.center) { d in
                                d[.bottom] - 7
                            }
                        Spacer()
                        if implementation1.isMultipleDestination {
                            Image(systemName: "point.3.filled.connected.trianglepath.dotted")
                                .font(.title)
                        }
                        else {
                            VStack(spacing: 3) {
                                Text(addressesAndPorts.destination.address)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.5)
                                    .font(.system(size: 8))
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: 60)
                                Image(systemName: "house.fill")
                                    .font(.title)
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
