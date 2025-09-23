//
//  ServerEntity.swift
//  NodePass
//
//  Created by Junhui Lou on 9/19/25.
//

import AppIntents

struct ServerEntity: AppEntity {
    let id: String
    let name: String
    var url: String
    var key: String
    
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Server"
    static let defaultQuery = ServerQuery()
            
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}
