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
    var id: String = UUID().uuidString
    var name: String = ""
    var type: ImplementationType = ImplementationType.directForwardClient
    var position: Int = 0
    var serverID: String = ""
    var instanceID: String = ""
    var command: String = ""
    var fullCommand: String = ""
    
    var service: Service?
    
    init(name: String, type: ImplementationType, position: Int, serverID: String, instanceID: String, command: String, fullCommand: String) {
        self.id = UUID().uuidString
        self.name = name
        self.type = type
        self.position = position
        self.serverID = serverID
        self.instanceID = instanceID
        self.command = command
        self.fullCommand = fullCommand
    }
    
    func dryModifyTunnelAddress(address: String, isReturnFullCommand: Bool = false) -> String {
        let addressesAndPorts = NPCore.parseAddressesAndPorts(urlString: command)
        return NPCore.extractSchemePrefix(urlString: command) + address + ":" + addressesAndPorts.tunnel.port + "/" + addressesAndPorts.destination.address + ":" + addressesAndPorts.destination.port + "?" + NPCore.extractQueryParameterString(urlString: command, isFull: isReturnFullCommand)
    }
    
    func dryModifyTunnelPort(port: String, isReturnFullCommand: Bool = false) -> String {
        let addressesAndPorts = NPCore.parseAddressesAndPorts(urlString: command)
        return NPCore.extractSchemePrefix(urlString: command) + addressesAndPorts.tunnel.address + ":" + port + "/" + addressesAndPorts.destination.address + ":" + addressesAndPorts.destination.port + "?" + NPCore.extractQueryParameterString(urlString: command, isFull: isReturnFullCommand)
    }
    
    func dryModifyDestinationAddress(address: String, isReturnFullCommand: Bool = false) -> String {
        let addressesAndPorts = NPCore.parseAddressesAndPorts(urlString: command)
        return NPCore.extractSchemePrefix(urlString: command) + addressesAndPorts.tunnel.address + ":" + addressesAndPorts.tunnel.port + "/" + address + ":" + addressesAndPorts.destination.port + "?" + NPCore.extractQueryParameterString(urlString: command, isFull: isReturnFullCommand)
    }
    
    func dryModifyDestinationPort(port: String, isReturnFullCommand: Bool = false) -> String {
        let addressesAndPorts = NPCore.parseAddressesAndPorts(urlString: command)
        return NPCore.extractSchemePrefix(urlString: command) + addressesAndPorts.tunnel.address + ":" + addressesAndPorts.tunnel.port + "/" + addressesAndPorts.destination.address + ":" + port + "?" + NPCore.extractQueryParameterString(urlString: command, isFull: isReturnFullCommand)
    }
}
