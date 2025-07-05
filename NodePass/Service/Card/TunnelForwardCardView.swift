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
    
    var body: some View {
        if service.type == .tunnelForward {
            VStack(spacing: 20) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Tunnel Forward")
                            .foregroundStyle(.gray)
                            .font(.caption)
                            .bold()
                        Text(service.name!)
                    }
                    Spacer()
                }
                
                HStack {
                    Image(systemName: "laptopcomputer.and.iphone")
                        .font(.title)
                    Spacer()
                    Image(systemName: "arrowshape.right")
                    Spacer()
                    VStack(spacing: 3) {
                        Text(service.implementations![0].serverName!)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .font(.system(size: 8))
                            .foregroundStyle(.gray)
                            .frame(maxWidth: 60)
                        Image(systemName: "airplane.cloud")
                            .font(.title)
                        Text("\(Image(systemName: "arrow.right")) \(service.implementations![0].destinationPort!, format: .number.grouping(.never))")
                            .font(.system(size: 8))
                    }
                    Spacer()
                    Image(systemName: "arrowshape.right")
                    Spacer()
                    VStack(spacing: 3) {
                        Text(service.implementations![1].serverName!)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .font(.system(size: 8))
                            .foregroundStyle(.gray)
                            .frame(maxWidth: 60)
                        Image(systemName: "airplane.arrival")
                            .font(.title)
                        Text("\(Image(systemName: "arrow.left")) \(service.implementations![1].destinationPort!, format: .number.grouping(.never))")
                            .font(.system(size: 8))
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .foregroundStyle(.white.opacity(0.01))
            )
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
        }
        else {
            Image(systemName: "exclamationmark.circle")
                .foregroundStyle(.red)
        }
    }
}
