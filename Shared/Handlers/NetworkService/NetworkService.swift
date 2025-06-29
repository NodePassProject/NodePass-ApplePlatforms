//
//  NetworkService.swift
//  NodePass
//
//  Created by Junhui Lou on 6/29/25.
//

import Foundation

final class NetworkService {
    private let session: URLSession
    
    init() {
        self.session = UnsafeSSLURLSession.create()
    }
    
    func request(
        _ endpoint: APIEndpoint,
        maxRetries: Int = 1,
        retryDelay: TimeInterval = 1.0,
        completion: @escaping (Result<Void, NetworkError>) -> Void
    ) {
        guard let url = buildURL(from: endpoint) else {
            completion(.failure(.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        
        var headers = endpoint.headers ?? [:]
        headers["Content-Type"] = "application/json"
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        
        if let parameters = endpoint.parameters {
            request.httpBody = try? JSONSerialization.data(withJSONObject: parameters)
        }
        
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(.requestFailed(error)))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(.invalidResponse))
                return
            }
            
            if httpResponse.statusCode == 401 {
                completion(.failure(.unauthorized))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                let message = data.flatMap { try? JSONDecoder().decode(ErrorResponse.self, from: $0) }?.message
                completion(.failure(.serverError(statusCode: httpResponse.statusCode, message: message)))
                return
            }
            
            completion(.success(()))
        }
        
        task.resume()
    }
    
    func request<T: Decodable>(
        _ endpoint: APIEndpoint,
        expecting type: T.Type,
        maxRetries: Int = 1,
        retryDelay: TimeInterval = 1.0,
        completion: @escaping (Result<APIResponse<T>, NetworkError>) -> Void
    ) {
        guard let url = buildURL(from: endpoint) else {
            completion(.failure(.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        
        var headers = endpoint.headers ?? [:]
        headers["Content-Type"] = "application/json"
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        
        if let parameters = endpoint.parameters {
            request.httpBody = try? JSONSerialization.data(withJSONObject: parameters)
        }
        
        let task = session.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                completion(.failure(.requestFailed(error)))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(.invalidResponse))
                return
            }
            
            if httpResponse.statusCode == 401 {
                completion(.failure(.unauthorized))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                let message = data.flatMap { try? JSONDecoder().decode(ErrorResponse.self, from: $0) }?.message
                completion(.failure(.serverError(statusCode: httpResponse.statusCode, message: message)))
                return
            }
            
            guard let data = data else {
                completion(.failure(.invalidResponse))
                return
            }
            
            do {
                let decoder = JSONDecoder()
                let decoded = try decoder.decode(type, from: data)
                let apiResponse = APIResponse(value: decoded, response: httpResponse)
                completion(.success(apiResponse))
            } catch let decodingError as DecodingError {
                let rawJSON = String(data: data, encoding: .utf8)
                printDecodingError(decodingError, rawJSON: rawJSON)

                completion(.failure(.decodingFailed(decodingError)))
            } catch {
                completion(.failure(.requestFailed(error)))
            }
        }
        
        task.resume()
    }
    
    private func buildURL(from endpoint: APIEndpoint) -> URL? {
        var components = URLComponents()
        components.scheme = endpoint.baseURL.scheme
        components.host = endpoint.baseURL.host
        components.port = endpoint.baseURL.port
        components.path = endpoint.baseURL.path + endpoint.path
        
        if let queries = endpoint.queries {
            components.queryItems = queries.map {
                URLQueryItem(name: $0.key, value: "\($0.value)")
            }
        }
        
        return components.url
    }
    
    private func printDecodingError(_ error: DecodingError, rawJSON: String?) {
        print("\n❌ DECODING ERROR =================================")
        
        switch error {
        case .typeMismatch(let type, let context):
            print("Type mismatch for type: \(type)")
            print("Coding path: \(context.codingPath.map { $0.stringValue }.joined(separator: " → "))")
            print("Debug description: \(context.debugDescription)")
            
        case .valueNotFound(let type, let context):
            print("Value not found for type: \(type)")
            print("Coding path: \(context.codingPath.map { $0.stringValue }.joined(separator: " → "))")
            print("Debug description: \(context.debugDescription)")
            
        case .keyNotFound(let key, let context):
            print("Key not found: \(key.stringValue)")
            print("Coding path: \(context.codingPath.map { $0.stringValue }.joined(separator: " → "))")
            print("Debug description: \(context.debugDescription)")
            
        case .dataCorrupted(let context):
            print("Data corrupted:")
            print("Debug description: \(context.debugDescription)")
            
        @unknown default:
            print("Unknown decoding error")
        }
        
        if let json = rawJSON {
            print("\n📄 RAW JSON RESPONSE:")
            if json.count > 2000 {
                print(String(json.prefix(2000)) + "... [TRUNCATED]")
                print("Full JSON length: \(json.count) characters")
            } else {
                print(json)
            }
        } else {
            print("No JSON data available")
        }
        
        print("=================================================\n")
    }
}
