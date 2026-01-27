//
//  DirectForwardCardView.swift
//  NodePass
//
//  Created by Junhui Lou on 7/4/25.
//

import SwiftUI
import SwiftData

struct DirectForwardCardView: View {
    let service: Service
    var isPreview: Bool = false
    
    @Query private var servers: [Server]
    
    @State private var heightForMainImages: CGFloat?
    
    var body: some View {
        if service.type == .directForward {
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
                    HStack {
                        Text("Direct Forward")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                            .bold()
                        Spacer()
                        if service.isConfigurationInvalid {
                            Label("Configuration Invalid", systemImage: "exclamationmark.triangle.fill")
                                .font(.caption2)
                                .foregroundStyle(.red)
                        }
                    }
                    Text(service.name)
                }
                Spacer()
            }
            
            HStack(alignment: .imageAlignment) {
                let implementation = service.implementations!.first(where: { $0.position == 0 })!
                let serverName = servers.first(where: { $0.id == implementation.serverID })?.name ?? String(localized: isPreview ? "Select" : "Unknown")
                let addressesAndPorts = NPCore.parseAddressesAndPorts(urlString: implementation.command)
                Image(systemName: "laptopcomputer.and.iphone")
                    .font(.title)
                    .modifier(EqualHeightModifier(height: $heightForMainImages, alignment: .center))
                    .alignmentGuide(.imageAlignment) { d in d[VerticalAlignment.center] }
                Spacer()
                Image(systemName: "arrowshape.right")
                    .alignmentGuide(.imageAlignment) { d in d[VerticalAlignment.center] }
                Spacer()
                VStack(spacing: 3) {
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
                Spacer()
                if implementation.isMultipleDestination {
                    VStack(spacing: 3) {
                        Text("\(implementation.destinationCount) target(s)")
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
        .padding()
    }
}
