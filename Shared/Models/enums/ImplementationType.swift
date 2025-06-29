//
//  ImplementationType.swift
//  NodePass
//
//  Created by Junhui Lou on 7/1/25.
//

enum ImplementationType: String, Codable {
    case natPassthroughServer = "natPassthroughServer"
    case natPassthroughClient = "natPassthroughClient"
    case directForwardClient = "directForwardClient"
    case tunnelForwardServer = "tunnelForwardServer"
    case tunnelForwardClient = "tunnelForwardClient"
}
