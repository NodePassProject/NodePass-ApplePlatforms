//
//  Instance.swift
//  NodePass
//
//  Created by Junhui Lou on 6/28/25.
//

import Foundation

struct Instance: Identifiable, Codable, Equatable {
    let id: String
    let type: InstanceType
    let status: InstanceStatus
    let url: String
    let tcpReceive: Int
    let tcpTransmit: Int
    let udpReceive: Int
    let udpTransmit: Int
    
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case status
        case url
        case tcpReceive = "tcprx"
        case tcpTransmit = "tcptx"
        case udpReceive = "udprx"
        case udpTransmit = "udptx"
    }
}
