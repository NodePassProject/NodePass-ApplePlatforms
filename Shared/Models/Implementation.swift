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
    var isMultipleDestination: Bool {
        destinationCount > 1
    }
    var destinationCount: Int {
        command.filter { $0 == "," }.count + 1
    }
    
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
}
