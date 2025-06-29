//
//  InstanceStatus.swift
//  NodePass
//
//  Created by Junhui Lou on 7/1/25.
//

enum InstanceStatus: Codable, Equatable {
    case running
    case stopped
    case error
    case other(String)
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        
        switch rawValue.lowercased() {
        case "running": self = .running
        case "stopped": self = .stopped
        case "error": self = .error
        default: self = .other(rawValue)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .running: try container.encode("running")
        case .stopped: try container.encode("stopped")
        case .error: try container.encode("error")
        case .other(let value): try container.encode(value)
        }
    }
    
    var stringValue: String {
        switch self {
        case .running: return "running"
        case .stopped: return "stopped"
        case .error: return "error"
        case .other(let value): return value
        }
    }
}
