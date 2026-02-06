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
    var id: String = UUID().uuidString
    var timestamp: Date = Date()
    var name: String = ""
    var url: String = ""
    var key: String = ""
    var isEnabled: Bool = true
    
    init(name: String, url: String, key: String, isEnabled: Bool = true) {
        self.id = UUID().uuidString
        self.timestamp = Date()
        self.name = name
        self.url = url
        self.key = key
        self.isEnabled = isEnabled
    }
    
    func getHost() -> String {
        let urlComponents = URLComponents(string: url)!
        let host = urlComponents.host!
        
        return host
    }
}
