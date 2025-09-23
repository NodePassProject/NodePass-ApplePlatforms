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
    let memoryUsed: Int64?
    let memoryTotal: Int64?
    let swapUsed: Int64?
    let swapTotal: Int64?
    let networkReceive: Int64?
    let networkTransmit: Int64?
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
        case memoryUsed = "mem_used"
        case memoryTotal = "mem_total"
        case swapUsed = "swap_used"
        case swapTotal = "swap_total"
        case networkReceive = "netrx"
        case networkTransmit = "nettx"
        case systemUptime = "sysup"
        case version = "ver"
        case name
        case uptime
        case logLevel = "log"
        case tlsLevel = "tls"
    }
}
