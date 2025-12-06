//
//  Instance+Transport.swift
//  NodePass
//
//  Created by Junhui Lou on 12/6/25.
//

extension Instance {
    enum Transport: String, CaseIterable {
        case tcp = "0"
        case quic = "1"
        case websocket = "2"
        
        var localizedName: String {
            switch(self) {
            case .tcp:
                return "TCP"
            case .quic:
                return "QUIC"
            case .websocket:
                return "WebSocket"
            }
        }
    }
}
