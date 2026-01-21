//
//  InstanceParameter.swift
//  NodePass
//
//  Created by Yosebyte on 1/21/26.
//

import Foundation

struct InstanceParameter: Identifiable, Equatable {
    let id: UUID
    var key: String
    var value: String
    var position: Int
    
    init(position: Int, key: String = "", value: String = "") {
        self.id = UUID()
        self.position = position
        self.key = key
        self.value = value
    }
}
