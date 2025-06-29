//
//  APIEndpoint.swift
//  NodePass
//
//  Created by Junhui Lou on 6/29/25.
//

import Foundation

protocol APIEndpoint {
    var baseURL: URL { get }
    var path: String { get }
    var method: HTTPMethod { get }
    var headers: [String: String]? { get }
    var queries: [String: Any]? { get }
    var parameters: [String: Any]? { get }
}
