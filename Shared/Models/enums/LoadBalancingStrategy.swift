//
//  LoadBalancingStrategy.swift
//  NodePass
//
//  Created by Yosebyte on 1/23/26.
//

enum LoadBalancingStrategy: String, CaseIterable {
    case roundRobin = "0"
    case optimalLatency = "1"
    case primaryBackup = "2"
    
    var displayName: String {
        switch self {
        case .roundRobin:
            return "Round Robin"
        case .optimalLatency:
            return "Optimal Latency"
        case .primaryBackup:
            return "Primary-Backup"
        }
    }
}
