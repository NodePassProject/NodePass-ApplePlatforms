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
    case updateInstance(baseURLString: String, apiKey: String, id: String, url: String)
    case updateInstanceStatus(baseURLString: String, apiKey: String, id: String, action: String)
    case updateInstancePeer(baseURLString: String, apiKey: String, id: String, serviceAlias: String, serviceId: String, serviceType: String)
    
    var baseURL: URL {
        switch self {
        case .listInstances(let baseURLString, _): return URL(string: baseURLString)!
        case .createInstance(let baseURLString, _, _): return URL(string: baseURLString)!
        case .deleteInstance(let baseURLString, _, _): return URL(string: baseURLString)!
        case .updateInstance(let baseURLString, _, _, _): return URL(string: baseURLString)!
        case .updateInstanceStatus(let baseURLString, _, _, _): return URL(string: baseURLString)!
        case .updateInstancePeer(let baseURLString, _, _, _, _, _): return URL(string: baseURLString)!
        }
    }
    
    var path: String {
        switch self {
        case .listInstances: return "/instances"
        case .createInstance: return "/instances"
        case .deleteInstance(_, _, let id): return "/instances/\(id)"
        case .updateInstance(_, _, let id, _): return "/instances/\(id)"
        case .updateInstanceStatus(_, _, let id, _): return "/instances/\(id)"
        case .updateInstancePeer(_, _, let id, _, _, _): return "/instances/\(id)"
        }
    }
    
    var method: HTTPMethod {
        switch self {
        case .listInstances: return .get
        case .createInstance: return .post
        case .deleteInstance: return .delete
        case .updateInstance: return .put
        case .updateInstanceStatus: return .patch
        case .updateInstancePeer: return .patch
        }
    }
    
    var headers: [String: String]? {
        switch self {
        case .listInstances(_, let apiKey): return ["X-API-Key": apiKey]
        case .createInstance(_, let apiKey, _): return ["X-API-Key": apiKey]
        case .deleteInstance(_, let apiKey, _): return ["X-API-Key": apiKey]
        case .updateInstance(_, let apiKey, _, _): return ["X-API-Key": apiKey]
        case .updateInstanceStatus(_, let apiKey, _, _): return ["X-API-Key": apiKey]
        case .updateInstancePeer(_, let apiKey, _, _, _, _): return ["X-API-Key": apiKey]
        }
    }
    
    var queries: [String : Any]? {
        switch self {
        case .listInstances: return nil
        case .createInstance: return nil
        case .deleteInstance: return nil
        case .updateInstance: return nil
        case .updateInstanceStatus: return nil
        case .updateInstancePeer: return nil
        }
    }
    
    var parameters: [String: Any]? {
        switch self {
        case .listInstances: return nil
        case .createInstance(_, _, let url): return ["url": url]
        case .deleteInstance: return nil
        case .updateInstance(_, _, _, let url): return ["url": url]
        case .updateInstanceStatus(_, _, _, let action): return ["action": action]
        case .updateInstancePeer(_, _, _, let serviceAlias, let serviceId, let serviceType): return [
            "meta": [
                "peer": [
                    "alias": serviceAlias,
                    "sid": serviceId,
                    "type": serviceType
                ]
            ]
        ]
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
    
    func updateInstance(baseURLString: String, apiKey: String, id: String, url: String) async throws -> Instance {
        let endpoint = InstanceAPI.updateInstance(baseURLString: baseURLString, apiKey: apiKey, id: id, url: url)
        
        return try await withCheckedThrowingContinuation { continuation in
            networkService.request(endpoint, expecting: Instance.self) { result in
                continuation.resume(with: result.map { $0.value })
            }
        }
    }
    
    func updateInstanceStatus(baseURLString: String, apiKey: String, id: String, action: String) async throws {
        let endpoint = InstanceAPI.updateInstanceStatus(baseURLString: baseURLString, apiKey: apiKey, id: id, action: action)
        
        return try await withCheckedThrowingContinuation { continuation in
            networkService.request(endpoint) { result in
                continuation.resume(with: result)
            }
        }
    }
    
    func updateInstancePeer(baseURLString: String, apiKey: String, id: String, serviceAlias: String, serviceId: String, serviceType: String) async throws {
        let endpoint = InstanceAPI.updateInstancePeer(baseURLString: baseURLString, apiKey: apiKey, id: id, serviceAlias: serviceAlias, serviceId: serviceId, serviceType: serviceType)
        
        return try await withCheckedThrowingContinuation { continuation in
            networkService.request(endpoint) { result in
                continuation.resume(with: result)
            }
        }
    }
}
