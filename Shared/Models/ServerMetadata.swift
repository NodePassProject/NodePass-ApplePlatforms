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
    let cpu: Int?
    let memory: Int?
    let networkReceive: Int64?
    let networkTransmit: Int64?
    let diskRead: Int64?
    let diskWrite: Int64?
    let systemUptime: Int64?
    let version: String
    let name: String
    let uptime: Int64?
    let logLevel: String
    let tlsLevel: String
    
    enum CodingKeys: String, CodingKey {
        case os
        case architecture = "arch"
        case cpu
        case memory = "ram"
        case networkReceive = "netrx"
        case networkTransmit = "nettx"
        case diskRead = "diskr"
        case diskWrite = "diskw"
        case systemUptime = "sysup"
        case version = "ver"
        case name
        case uptime
        case logLevel = "log"
        case tlsLevel = "tls"
    }
}
