//
//  ConnectionMode.swift
//  NodePass
//
//  Created by Yosebyte on 1/23/26.
//

enum ConnectionMode: String, CaseIterable {
    case auto = "0"
    case singleEnd = "1"
    case dualEnd = "2"
    
    func displayName(forServer: Bool) -> String {
        if forServer {
            switch self {
            case .auto:
                return "Auto"
            case .singleEnd:
                return "Reverse"
            case .dualEnd:
                return "Forward"
            }
        } else {
            switch self {
            case .auto:
                return "Auto"
            case .singleEnd:
                return "Single-end"
            case .dualEnd:
                return "Dual-end"
            }
        }
    }
}
