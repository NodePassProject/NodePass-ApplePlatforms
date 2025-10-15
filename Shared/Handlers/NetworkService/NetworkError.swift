//
//  NetworkError.swift
//  NodePass
//
//  Created by Junhui Lou on 6/29/25.
//

import Foundation

enum NetworkError: Error, LocalizedError {
    case invalidURL
    case requestFailed(Error)
    case invalidResponse
    case unauthorized
    case decodingFailed(DecodingError)
    case serverError(statusCode: Int, message: String?)
    case custom(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return String(localized: "Invalid URL")
        case .requestFailed(let error): return String(localized: "Request Failed: \(error.localizedDescription)")
        case .invalidResponse: return String(localized: "Invalid Response")
        case .unauthorized: return String(localized: "Unauthorized")
        case .decodingFailed(let error): return String(localized: "Decoding Failed: \(error.localizedDescription)")
        case .serverError(let code, let message):
            return String(localized: "Server Error(\(code)): \(message ?? "Unknown Error")")
        case .custom(let message): return message
        }
    }
}
