//
//  ServiceCardView.swift
//  NodePass
//
//  Created by Junhui Lou on 7/1/25.
//

import SwiftUI

struct ServiceCardView: View {
    let service: Service
    
    var body: some View {
        switch(service.type) {
        case .natPassthrough:
            NATPassthroughCardView(service: service)
        case .directForward:
            DirectForwardCardView(service: service)
        case .tunnelForward, .tunnelForwardExternal:
            TunnelForwardCardView(service: service)
        }
    }
}
