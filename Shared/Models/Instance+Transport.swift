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
        case http2 = "3"
        
        var localizedName: String {
            switch(self) {
            case .tcp:
                return "TCP"
            case .quic:
                return "QUIC"
            case .websocket:
                return "WebSocket"
            case .http2:
                return "HTTP/2"
            }
        }
        
        var isRequireTLS: Bool {
            switch(self) {
            case .tcp:
                return false
            case .quic:
                return true
            case .websocket:
                return false
            case .http2:
                return true
            }
        }
    }
}
