//
//  TLSMode.swift
//  NodePass
//
//  Created by Yosebyte on 1/23/26.
//

enum TLSMode: String, CaseIterable {
    case none = "0"
    case selfSigned = "1"
    case custom = "2"
    
    var displayName: String {
        switch self {
        case .none:
            return "No TLS Encryption"
        case .selfSigned:
            return "Self-signed Certificate"
        case .custom:
            return "Trusted Certificate"
        }
    }
}
