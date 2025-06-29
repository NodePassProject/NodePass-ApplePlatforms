//
//  APIResponse.swift
//  NodePass
//
//  Created by Junhui Lou on 6/29/25.
//

import Foundation

struct APIResponse<T: Decodable> {
    let value: T
    let response: URLResponse
}
