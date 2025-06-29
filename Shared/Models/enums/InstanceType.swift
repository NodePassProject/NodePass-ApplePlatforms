//
//  InstanceType.swift
//  NodePass
//
//  Created by Junhui Lou on 7/1/25.
//

enum InstanceType: Codable, Equatable {
    case server
    case client
    case other(String)
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        
        switch rawValue.lowercased() {
        case "server": self = .server
        case "client": self = .client
        default: self = .other(rawValue)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .server: try container.encode("server")
        case .client: try container.encode("client")
        case .other(let value): try container.encode(value)
        }
    }
    
    var stringValue: String {
        switch self {
        case .server: return "server"
        case .client: return "client"
        case .other(let value): return value
        }
    }
}
