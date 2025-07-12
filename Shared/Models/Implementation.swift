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
    var instanceID: String?
    var command: String?
    
    var service: Service?
    
    init(name: String, type: ImplementationType, position: Int, serverID: String, instanceID: String, command: String) {
        self.id = "\(serverID)\(instanceID)\(command)"
        self.name = name
        self.type = type
        self.position = position
        self.serverID = serverID
        self.instanceID = instanceID
        self.command = command
    }
    
    func extractAddressesAndPorts() -> (tunnel: (address: String, port: String), destination: (address: String, port: String)) {
        let urlString = command!
        let schemePrefixes = ["server://", "client://"]
        var cleanedString = urlString
        for prefix in schemePrefixes {
            if urlString.hasPrefix(prefix) {
                cleanedString = String(urlString.dropFirst(prefix.count))
                break
            }
        }
        
        if let queryStartIndex = cleanedString.firstIndex(of: "?") {
            cleanedString = String(cleanedString[..<queryStartIndex])
        }
        
        
        let parts: (String, String)
        let slashIndex = cleanedString.firstIndex(of: "/")!
        let firstPart = String(cleanedString[..<slashIndex])
        let secondPart = String(cleanedString[cleanedString.index(after: slashIndex)...])
        parts = (firstPart, secondPart)
        
        func parsePart(_ part: String) -> (address: String, port: String) {
            let lastColonIndex = part.lastIndex(of: ":")!
            
            let address = String(part[..<lastColonIndex])
            let portStartIndex = part.index(after: lastColonIndex)
            let port = String(part[portStartIndex...])
            return (address, port)
        }
        
        return (
            tunnel: parsePart(parts.0),
            destination: parsePart(parts.1)
        )
    }
    
    func extractQueryParameters() -> [String: String] {
        let urlString = command!
        guard let questionMarkIndex = urlString.firstIndex(of: "?") else {
            return [:]
        }
        
        let queryStartIndex = urlString.index(after: questionMarkIndex)
        let queryString = String(urlString[queryStartIndex...])
        let keyValuePairs = queryString.components(separatedBy: "&")
        var parameters = [String: String]()
        for pair in keyValuePairs {
            let components = pair.components(separatedBy: "=")
            
            guard components.count >= 1 else { continue }
            
            let key = components[0]
            let value = components.count >= 2 ? components[1] : ""
            
            parameters[key] = value
        }
        
        return parameters
    }
}
