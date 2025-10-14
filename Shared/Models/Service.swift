//
//  Service.swift
//  NodePass
//
//  Created by Junhui Lou on 6/30/25.
//

import Foundation
import SwiftData

@Model
class Service {
    var id: UUID = UUID()
    var timestamp: Date = Date()
    var name: String = ""
    var type: ServiceType = ServiceType.directForward
    var implementations: [Implementation]?
    
    init(name: String, type: ServiceType, implementations: [Implementation]) {
        self.id = UUID()
        self.timestamp = Date()
        self.name = name
        self.type = type
        self.implementations = implementations
    }
}
