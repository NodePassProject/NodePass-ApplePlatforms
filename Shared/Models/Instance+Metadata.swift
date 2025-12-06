//
//  Instance+Metadata.swift
//  NodePass
//
//  Created by Junhui Lou on 12/6/25.
//

extension Instance {
    struct Metadata: Codable, Hashable {
        let peer: Peer
        let tags: Dictionary<String, String>
    }
    
    struct Peer: Codable, Hashable {
        let alias: String
        let serviceId: String
        let serviceType: String
        
        enum CodingKeys: String, CodingKey {
            case alias
            case serviceId = "sid"
            case serviceType = "type"
        }
    }
}
