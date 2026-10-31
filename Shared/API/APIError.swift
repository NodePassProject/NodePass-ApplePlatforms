//
//  APIError.swift
//  NodePass
//

import Foundation

nonisolated enum APIError: Error, LocalizedError, Sendable {
    case invalidBaseURL
    case transport(String)
    case invalidResponse
    case unauthorized
    case forbidden(String?)
    case notFound
    case conflict(String?)
    case badRequest(String?)
    case tooManyRequests(String?)
    case http(statusCode: Int, message: String?)
    case decoding(String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL: "The master URL is not valid."
        case .transport(let message): message
        case .invalidResponse: "The master returned an unexpected response."
        case .unauthorized: "Unauthorized. Check the API key."
        case .forbidden(let message): message ?? "This operation is not allowed."
        case .notFound: "Not found."
        case .conflict(let message): message ?? "Conflict."
        case .badRequest(let message): message ?? "The master rejected the request."
        case .tooManyRequests(let message): message ?? "Too many requests."
        case .http(let code, let message): message.map { "\($0) (HTTP \(code))" } ?? "HTTP \(code)"
        case .decoding(let message): "Could not read the response: \(message)"
        case .cancelled: "Cancelled."
        }
    }

    /// Short label suitable for compact status displays.
    var shortDescription: String {
        switch self {
        case .invalidBaseURL: "Invalid URL"
        case .transport: "Unreachable"
        case .invalidResponse: "Bad response"
        case .unauthorized: "Unauthorized"
        case .forbidden: "Forbidden"
        case .notFound: "Not found"
        case .conflict: "Conflict"
        case .badRequest: "Rejected"
        case .tooManyRequests: "Rate limited"
        case .http(let code, _): "HTTP \(code)"
        case .decoding: "Decoding failed"
        case .cancelled: "Cancelled"
        }
    }

    var isAuthenticationFailure: Bool {
        if case .unauthorized = self { return true }
        return false
    }

    var isConflict: Bool {
        if case .conflict = self { return true }
        return false
    }

    static func from(statusCode: Int, message: String?) -> APIError {
        switch statusCode {
        case 400: .badRequest(message)
        case 401: .unauthorized
        case 403: .forbidden(message)
        case 404: .notFound
        case 409: .conflict(message)
        case 429: .tooManyRequests(message)
        default: .http(statusCode: statusCode, message: message)
        }
    }

    /// Wraps any error as an `APIError`, preserving existing ones.
    static func wrap(_ error: any Error) -> APIError {
        if let apiError = error as? APIError { return apiError }
        if error is CancellationError { return .cancelled }
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorCancelled { return .cancelled }
        if let decodingError = error as? DecodingError { return .decoding(Self.describe(decodingError)) }
        return .transport(nsError.localizedDescription)
    }

    private static func describe(_ error: DecodingError) -> String {
        switch error {
        case .typeMismatch(let type, let context):
            "type mismatch for \(type) at \(context.codingPath.map(\.stringValue).joined(separator: "."))"
        case .valueNotFound(let type, let context):
            "missing \(type) at \(context.codingPath.map(\.stringValue).joined(separator: "."))"
        case .keyNotFound(let key, _):
            "missing key \(key.stringValue)"
        case .dataCorrupted(let context):
            context.debugDescription
        @unknown default:
            "unknown decoding error"
        }
    }
}
