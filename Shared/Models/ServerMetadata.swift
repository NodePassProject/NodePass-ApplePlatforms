//
//  ServerMetadata.swift
//  NodePass
//
//  Created by Junhui Lou on 7/19/25.
//

import Foundation

struct ServerMetadata: Identifiable, Codable, Equatable {
    var id: String? {
        serverID
    }
    var serverID: String?
    let os: String
    let architecture: String
    let version: String
    let name: String
    let uptime: Int64?
    let logLevel: String
    let tlsLevel: String
    
    enum CodingKeys: String, CodingKey {
        case os
        case architecture = "arch"
        case version = "ver"
        case name
        case uptime
        case logLevel = "log"
        case tlsLevel = "tls"
    }
}
