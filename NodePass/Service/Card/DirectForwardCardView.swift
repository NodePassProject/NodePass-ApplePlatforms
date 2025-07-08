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
    
    var body: some View {
        if service.type == .directForward {
            if #available(iOS 26.0, macOS 26.0, *) {
                cardContent
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .foregroundStyle(.white.opacity(0.01))
                    )
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
            }
            else {
                cardContent
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .foregroundStyle(.regularMaterial)
                    )
            }
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
                    Text("Direct Forward")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                        .bold()
                    Text(service.name!)
                }
                Spacer()
            }
            
            HStack {
                let implementation = service.implementations!.first(where: { $0.position == 0 })!
                let serverName = servers.first(where: { $0.id == implementation.serverID })?.name ?? String(localized: isPreview ? "Select" : "Unknown")
                let addressesAndPorts = implementation.extractAddressesAndPorts()
                Image(systemName: "laptopcomputer.and.iphone")
                    .font(.title)
                Spacer()
                Image(systemName: "arrowshape.right")
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
                    Text(addressesAndPorts.tunnel.port)
                        .font(.system(size: 8))
                }
                Spacer()
                Image(systemName: "arrowshape.right")
                Spacer()
                VStack(spacing: 3) {
                    Text(addressesAndPorts.destination.address)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: 60)
                    Image(systemName: "airplane.arrival")
                        .font(.title)
                    Text(addressesAndPorts.destination.port)
                        .font(.system(size: 8))
                }
            }
        }
        .padding()
    }
}
