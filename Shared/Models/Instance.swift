//
//  Instance.swift
//  NodePass
//
//  Created by Junhui Lou on 6/28/25.
//

import Foundation

struct Instance: Identifiable, Codable, Equatable {
    let id: String
    let type: Scheme
    let status: Status
    let url: String
    let config: String?
    let tcp: Int?
    let udp: Int?
    let tcpReceive: Int64
    let tcpTransmit: Int64
    let udpReceive: Int64
    let udpTransmit: Int64
    let ping: Int?
    let poolConnectionCount: Int?
    let metadata: Metadata?
    
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case status
        case url
        case config
        case tcp = "tcps"
        case udp = "udps"
        case tcpReceive = "tcprx"
        case tcpTransmit = "tcptx"
        case udpReceive = "udprx"
        case udpTransmit = "udptx"
        case ping = "ping"
        case poolConnectionCount = "pool"
        case metadata = "meta"
    }
}
