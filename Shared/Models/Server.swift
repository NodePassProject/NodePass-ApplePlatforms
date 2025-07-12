//
//  Server.swift
//  NodePass
//
//  Created by Junhui Lou on 6/28/25.
//

import Foundation
import SwiftData

@Model
class Server {
    var id: String?
    var timestamp: Date?
    var name: String?
    var url: String?
    var key: String?
    
    init(name: String, url: String, key: String) {
        self.id = url
        self.timestamp = Date()
        self.name = name
        self.url = url
        self.key = key
    }
    
    func getHost() -> String {
        let urlComponents = URLComponents(string: url!)!
        let host = urlComponents.host!
        
        return host
    }
}
