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
            VStack(spacing: 20) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("NAT Passthrough")
                            .foregroundStyle(.secondary)
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
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: 60)
                        Image(systemName: "cloud.fill")
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
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: 60)
                        Image(systemName: "house.fill")
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
