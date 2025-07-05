//
//  Implementation.swift
//  NodePass
//
//  Created by Junhui Lou on 7/1/25.
//

import Foundation
import SwiftData

@Model
class Implementation {
    var id: String?
    var name: String?
    var type: ImplementationType?
    var position: Int?
    var serverID: String?
    var serverName: String?
    var instanceID: String?
    var tunnelAddress: String?
    var tunnelPort: Int?
    var destinationAddress: String?
    var destinationPort: Int?
    var command: String?
    
    var service: Service?
    
    init(name: String, type: ImplementationType, position: Int, serverID: String, serverName: String, instanceID: String, tunnelAddress: String, tunnelPort: Int, destinationAddress: String, destinationPort: Int, command: String) {
        self.id = UUID().uuidString
        self.name = name
        self.type = type
        self.position = position
        self.serverID = serverID
        self.serverName = serverName
        self.instanceID = instanceID
        self.tunnelAddress = tunnelAddress
        self.tunnelPort = tunnelPort
        self.destinationAddress = destinationAddress
        self.destinationPort = destinationPort
        self.command = command
    }
}
