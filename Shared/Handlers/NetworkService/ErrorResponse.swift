//
//  ErrorResponse.swift
//  NodePass
//
//  Created by Junhui Lou on 6/29/25.
//

@preconcurrency import Foundation

struct ErrorResponse: Sendable, Decodable {
    let message: String
    
    nonisolated static func decode(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let message = json["message"] as? String else {
            return nil
        }
        return message
    }
}
