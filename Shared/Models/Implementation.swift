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
    var fullCommand: String?
    
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
    
    func extractSchemePrefix() -> String {
        let urlString = command!
        let schemePrefixes = ["server://", "client://"]
        for prefix in schemePrefixes {
            if urlString.hasPrefix(prefix) {
                return prefix
            }
        }
        return ""
    }
    
    func extractQueryParameterString(isFull: Bool = false) -> String {
        let urlString = isFull ? (fullCommand ?? command!) : command!
        guard let questionMarkIndex = urlString.firstIndex(of: "?") else {
            return ""
        }
        return String(urlString[urlString.index(after: questionMarkIndex)...])
    }
    
    func parseAddressesAndPorts() -> (tunnel: (address: String, port: String), destination: (address: String, port: String)) {
        let urlString = command!
        let schemePrefixes = ["server://", "client://"]
        var stringWithoutPrefix = ""
        for prefix in schemePrefixes {
            if urlString.hasPrefix(prefix) {
                stringWithoutPrefix = String(urlString.dropFirst(prefix.count))
                break
            }
        }
        
        var stringWithoutPrefixAndParameters = stringWithoutPrefix
        if let queryStartIndex = stringWithoutPrefix.firstIndex(of: "?") {
            stringWithoutPrefixAndParameters = String(stringWithoutPrefix[..<queryStartIndex])
        }
        
        let stringParts: (String, String)
        let slashIndex = stringWithoutPrefixAndParameters.firstIndex(of: "/")!
        let tunnalStringPart = String(stringWithoutPrefixAndParameters[..<slashIndex])
        let destinationStringPart = String(stringWithoutPrefixAndParameters[stringWithoutPrefixAndParameters.index(after: slashIndex)...])
        stringParts = (tunnalStringPart, destinationStringPart)
        
        func parseStringPart(_ part: String) -> (address: String, port: String) {
            let lastColonIndex = part.lastIndex(of: ":")!
            
            let address = String(part[..<lastColonIndex])
            let portStartIndex = part.index(after: lastColonIndex)
            let port = String(part[portStartIndex...])
            return (address, port)
        }
        
        return (
            tunnel: parseStringPart(stringParts.0),
            destination: parseStringPart(stringParts.1)
        )
    }
    
    func parseQueryParameters(isFull: Bool = false) -> [String: String] {
        let queryString = extractQueryParameterString(isFull: isFull)
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
    
    func dryModifyTunnelAddress(address: String, isReturnFullCommand: Bool = false) -> String {
        let addressesAndPorts = parseAddressesAndPorts()
        return extractSchemePrefix() + address + ":" + addressesAndPorts.tunnel.port + "/" + addressesAndPorts.destination.address + ":" + addressesAndPorts.destination.port + "?" + extractQueryParameterString(isFull: isReturnFullCommand)
    }
    
    func dryModifyTunnelPort(port: String, isReturnFullCommand: Bool = false) -> String {
        let addressesAndPorts = parseAddressesAndPorts()
        return extractSchemePrefix() + addressesAndPorts.tunnel.address + ":" + port + "/" + addressesAndPorts.destination.address + ":" + addressesAndPorts.destination.port + "?" + extractQueryParameterString(isFull: isReturnFullCommand)
    }
    
    func dryModifyDestinationAddress(address: String, isReturnFullCommand: Bool = false) -> String {
        let addressesAndPorts = parseAddressesAndPorts()
        return extractSchemePrefix() + addressesAndPorts.tunnel.address + ":" + addressesAndPorts.tunnel.port + "/" + address + ":" + addressesAndPorts.destination.port + "?" + extractQueryParameterString(isFull: isReturnFullCommand)
    }
    
    func dryModifyDestinationPort(port: String, isReturnFullCommand: Bool = false) -> String {
        let addressesAndPorts = parseAddressesAndPorts()
        return extractSchemePrefix() + addressesAndPorts.tunnel.address + ":" + addressesAndPorts.tunnel.port + "/" + addressesAndPorts.destination.address + ":" + port + "?" + extractQueryParameterString(isFull: isReturnFullCommand)
    }
}
