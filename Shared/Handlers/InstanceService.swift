//
//  InstanceService.swift
//  NodePass
//
//  Created by Junhui Lou on 6/29/25.
//

import Foundation

enum InstanceAPI: APIEndpoint {
    case listInstances(baseURLString: String, apiKey: String)
    case createInstance(baseURLString: String, apiKey: String, url: String)
    case deleteInstance(baseURLString: String, apiKey: String, id: String)
    
    var baseURL: URL {
        switch self {
        case .listInstances(let baseURLString, _): return URL(string: baseURLString)!
        case .createInstance(let baseURLString, _, _): return URL(string: baseURLString)!
        case .deleteInstance(let baseURLString, _, _): return URL(string: baseURLString)!
        }
    }
    
    var path: String {
        switch self {
        case .listInstances: return "/instances"
        case .createInstance: return "/instances"
        case .deleteInstance(_, _, let id): return "/instances/\(id)"
        }
    }
    
    var method: HTTPMethod {
        switch self {
        case .listInstances: return .get
        case .createInstance: return .post
        case .deleteInstance: return .delete
        }
    }
    
    var headers: [String: String]? {
        switch self {
        case .listInstances(_, let apiKey): return ["X-API-Key": apiKey]
        case .createInstance(_, let apiKey, _): return ["X-API-Key": apiKey]
        case .deleteInstance(_, let apiKey, _): return ["X-API-Key": apiKey]
        }
    }
    
    var queries: [String : Any]? {
        switch self {
        case .listInstances: return nil
        case .createInstance: return nil
        case .deleteInstance: return nil
        }
    }
    
    var parameters: [String: Any]? {
        switch self {
        case .listInstances: return nil
        case .createInstance(_, _, let url): return ["url": url]
        case .deleteInstance: return nil
        }
    }
}

class InstanceService {
    private let networkService: NetworkService
    
    init(networkService: NetworkService = .init()) {
        self.networkService = networkService
    }
    
    func listInstances(baseURLString: String, apiKey: String) async throws -> [Instance] {
        let endpoint = InstanceAPI.listInstances(baseURLString: baseURLString, apiKey: apiKey)
        
        return try await withCheckedThrowingContinuation { continuation in
            networkService.request(endpoint, expecting: [Instance].self) { result in
                continuation.resume(with: result.map { $0.value })
            }
        }
    }
    
    func createInstance(baseURLString: String, apiKey: String, url: String) async throws -> Instance {
        let endpoint = InstanceAPI.createInstance(baseURLString: baseURLString, apiKey: apiKey, url: url)
        
        return try await withCheckedThrowingContinuation { continuation in
            networkService.request(endpoint, expecting: Instance.self) { result in
                continuation.resume(with: result.map { $0.value })
            }
        }
    }
    
    func deleteInstance(baseURLString: String, apiKey: String, id: String) async throws {
        let endpoint = InstanceAPI.deleteInstance(baseURLString: baseURLString, apiKey: apiKey, id: id)
        
        return try await withCheckedThrowingContinuation { continuation in
            networkService.request(endpoint) { result in
                continuation.resume(with: result)
            }
        }
    }
}
