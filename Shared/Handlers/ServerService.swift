//
//  ServerService.swift
//  NodePass
//
//  Created by Junhui Lou on 7/20/25.
//

import Foundation

enum ServerAPI: APIEndpoint {
    case getServerInfo(baseURLString: String, apiKey: String)
    
    var baseURL: URL {
        switch self {
        case .getServerInfo(let baseURLString, _): return URL(string: baseURLString)!
        }
    }
    
    var path: String {
        switch self {
        case .getServerInfo: return "/info"
        }
    }
    
    var method: HTTPMethod {
        switch self {
        case .getServerInfo: return .get
        }
    }
    
    var headers: [String: String]? {
        switch self {
        case .getServerInfo(_, let apiKey): return ["X-API-Key": apiKey]
        }
    }
    
    var queries: [String : Any]? {
        switch self {
        case .getServerInfo: return nil
        }
    }
    
    var parameters: [String: Any]? {
        switch self {
        case .getServerInfo: return nil
        }
    }
}

class ServerService {
    private let networkService: NetworkService
    
    init(networkService: NetworkService = .init()) {
        self.networkService = networkService
    }
    
    func getServerInfo(baseURLString: String, apiKey: String) async throws -> ServerMetadata {
        let endpoint = ServerAPI.getServerInfo(baseURLString: baseURLString, apiKey: apiKey)
        
        return try await withCheckedThrowingContinuation { continuation in
            networkService.request(endpoint, expecting: ServerMetadata.self) { result in
                continuation.resume(with: result.map { $0.value })
            }
        }
    }
}
