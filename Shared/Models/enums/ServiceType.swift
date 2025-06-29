//
//  ServiceType.swift
//  NodePass
//
//  Created by Junhui Lou on 7/1/25.
//

enum ServiceType: String, Codable, Equatable {
    case natPassthrough = "natPassthrough"
    case directForward = "directForward"
    case tunnelForward = "tunnelForward"
}
