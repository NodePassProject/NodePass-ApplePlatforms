//
//  MasterClient.swift
//  NodePass
//
//  Typed, async client for the NodePass / OpenCtrl master contract.
//

import Foundation
import OSLog

nonisolated let masterClientLog = Logger(subsystem: "com.argsment.NodePass", category: "MasterClient")

/// Everything needed to talk to one master.
nonisolated struct MasterCredentials: Hashable, Sendable {
    var baseURL: URL
    var apiKey: String
    var trustsSelfSignedCertificates: Bool = true

    /// Normalizes a user-entered base URL: trims whitespace and a trailing slash, requires http(s) and a host.
    static func normalizeBaseURL(_ string: String) -> URL? {
        var trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        while trimmed.hasSuffix("/") { trimmed.removeLast() }
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https",
              let host = url.host(), !host.isEmpty else { return nil }
        return url
    }
}

/// Raw response for the API console.
nonisolated struct RawResponse: Sendable {
    var statusCode: Int
    var headers: [String: String]
    var body: Data
    var duration: TimeInterval

    var bodyText: String { String(decoding: body, as: UTF8.self) }

    /// Pretty-printed JSON when the body is JSON, otherwise the raw text.
    var prettyBody: String {
        guard let object = try? JSONSerialization.jsonObject(with: body),
              let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]) else {
            return bodyText
        }
        return String(decoding: data, as: UTF8.self)
    }
}

actor MasterClient {
    let credentials: MasterCredentials

    private let requestSession: URLSession
    private let streamSession: URLSession

    init(credentials: MasterCredentials, requestTimeout: TimeInterval = 10) {
        self.credentials = credentials
        let delegate = TrustPolicyDelegate(trustsSelfSignedCertificates: credentials.trustsSelfSignedCertificates)

        let requestConfiguration = URLSessionConfiguration.ephemeral
        requestConfiguration.timeoutIntervalForRequest = requestTimeout
        requestConfiguration.timeoutIntervalForResource = requestTimeout * 3
        requestConfiguration.waitsForConnectivity = false
        requestSession = URLSession(configuration: requestConfiguration, delegate: delegate, delegateQueue: nil)

        let streamConfiguration = URLSessionConfiguration.ephemeral
        // SSE streams can stay silent for a long time when no instance is running.
        streamConfiguration.timeoutIntervalForRequest = 24 * 60 * 60
        streamConfiguration.timeoutIntervalForResource = 7 * 24 * 60 * 60
        streamSession = URLSession(configuration: streamConfiguration, delegate: delegate, delegateQueue: nil)
    }

    deinit {
        requestSession.invalidateAndCancel()
        streamSession.invalidateAndCancel()
    }

    // MARK: Master

    func info() async throws -> MasterInfo {
        try await send(.info, expecting: MasterInfo.self)
    }

    func updateMasterAlias(_ alias: String) async throws -> MasterInfo {
        try await send(.updateMasterAlias(alias), expecting: MasterInfo.self)
    }

    func tcping(target: String) async throws -> TCPingResult {
        try await send(.tcping(target: target), expecting: TCPingResult.self)
    }

    /// Returns the OpenAPI document if the master publishes one (NodePass only).
    func openAPISpecification() async throws -> Data {
        try await send(.openAPISpecification).body
    }

    /// The pseudo-instance that carries the API key (`url`) and master ID (`config`).
    func apiKeyInstance() async throws -> Instance {
        try await send(.instance(NPCore.apiKeyInstanceID), expecting: Instance.self)
    }

    /// Rotates the API key. The returned string is the new key; the current key stops working immediately.
    func regenerateAPIKey() async throws -> String {
        let instance = try await send(.patchInstance(NPCore.apiKeyInstanceID, InstancePatch(action: .restart)), expecting: Instance.self)
        return instance.url
    }

    // MARK: Instances

    func instances() async throws -> [Instance] {
        try await send(.listInstances, expecting: [Instance].self)
    }

    func instance(id: String) async throws -> Instance {
        try await send(.instance(id), expecting: Instance.self)
    }

    func createInstance(url: String, alias: String?) async throws -> Instance {
        try await send(.createInstance(url: url, alias: alias?.isEmpty == true ? nil : alias), expecting: Instance.self)
    }

    /// Replaces the instance URL. A 409 means the URL is already identical; the current instance is returned in that case.
    func replaceInstanceURL(id: String, url: String) async throws -> Instance {
        do {
            return try await send(.replaceInstanceURL(id, url: url), expecting: Instance.self)
        } catch let error as APIError where error.isConflict {
            return try await instance(id: id)
        }
    }

    func patchInstance(id: String, _ patch: InstancePatch) async throws -> Instance {
        try await send(.patchInstance(id, patch), expecting: Instance.self)
    }

    func perform(_ action: InstanceAction, on id: String) async throws -> Instance {
        try await patchInstance(id: id, InstancePatch(action: action))
    }

    func setAlias(_ alias: String, for id: String) async throws -> Instance {
        try await patchInstance(id: id, InstancePatch(alias: alias))
    }

    func setRestartPolicy(_ enabled: Bool, for id: String) async throws -> Instance {
        try await patchInstance(id: id, InstancePatch(restart: enabled))
    }

    func setMeta(peer: Instance.Peer?, tags: [String: String]?, for id: String) async throws -> Instance {
        try await patchInstance(id: id, InstancePatch(meta: .init(peer: peer, tags: tags)))
    }

    func deleteInstance(id: String) async throws {
        _ = try await send(.deleteInstance(id))
    }

    // MARK: Raw access (API console)

    func rawRequest(method: HTTPMethod, path: String, body: String?) async throws -> RawResponse {
        var endpoint = MasterEndpoint(method: method, path: path.hasPrefix("/") ? path : "/" + path)
        if let body, !body.isEmpty { endpoint.body = Data(body.utf8) }
        let start = ContinuousClock.now
        let request = try makeRequest(endpoint)
        let (data, response) = try await perform(request, on: requestSession)
        let duration = start.duration(to: .now)
        var headers: [String: String] = [:]
        for (key, value) in response.allHeaderFields {
            headers["\(key)"] = "\(value)"
        }
        let seconds = Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
        return RawResponse(statusCode: response.statusCode, headers: headers, body: data, duration: seconds)
    }

    // MARK: Events

    /// Opens `GET /events` and yields decoded instance events until the connection drops.
    nonisolated func events() -> AsyncThrowingStream<InstanceEvent, any Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let request = try self.makeRequest(.events)
                    let (bytes, response) = try await self.streamSession.bytes(for: request)
                    guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
                    guard (200...299).contains(http.statusCode) else {
                        throw APIError.from(statusCode: http.statusCode, message: nil)
                    }
                    masterClientLog.debug("event stream opened: \(http.statusCode)")
                    var parser = ServerSentEventParser()
                    let decoder = JSONDecoder()
                    // `AsyncBytes.lines` drops empty lines, and SSE relies on the empty line as the
                    // event terminator, so split the stream into lines by hand.
                    var lineBuffer: [UInt8] = []
                    lineBuffer.reserveCapacity(4096)
                    for try await byte in bytes {
                        if byte != 0x0A {
                            lineBuffer.append(byte)
                            continue
                        }
                        try Task.checkCancellation()
                        let line = String(decoding: lineBuffer, as: UTF8.self)
                        lineBuffer.removeAll(keepingCapacity: true)
                        guard let event = parser.feed(line: line) else { continue }
                        guard event.event == nil || event.event == "instance" else { continue }
                        guard let data = event.data.data(using: .utf8), !data.isEmpty else { continue }
                        do {
                            continuation.yield(try decoder.decode(InstanceEvent.self, from: data))
                        } catch {
                            masterClientLog.error("event decode failed: \(APIError.wrap(error).localizedDescription, privacy: .public)")
                        }
                    }
                    masterClientLog.debug("event stream ended")
                    continuation.finish()
                } catch {
                    masterClientLog.error("event stream failed: \(APIError.wrap(error).localizedDescription, privacy: .public)")
                    continuation.finish(throwing: APIError.wrap(error))
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: Plumbing

    private struct Envelope {
        var body: Data
        var response: HTTPURLResponse
    }

    private func send<T: Decodable>(_ endpoint: MasterEndpoint, expecting type: T.Type) async throws -> T {
        let envelope = try await send(endpoint)
        let decoder = JSONDecoder()
        do {
            return try decoder.decode(type, from: envelope.body)
        } catch {
            throw APIError.wrap(error)
        }
    }

    private func send(_ endpoint: MasterEndpoint) async throws -> Envelope {
        let request = try makeRequest(endpoint)
        let (data, response) = try await perform(request, on: requestSession)
        guard (200...299).contains(response.statusCode) else {
            throw APIError.from(statusCode: response.statusCode, message: Self.errorMessage(from: data))
        }
        return Envelope(body: data, response: response)
    }

    private func perform(_ request: URLRequest, on session: URLSession) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
            return (data, http)
        } catch {
            throw APIError.wrap(error)
        }
    }

    nonisolated private func makeRequest(_ endpoint: MasterEndpoint) throws -> URLRequest {
        guard var components = URLComponents(url: credentials.baseURL, resolvingAgainstBaseURL: false) else {
            throw APIError.invalidBaseURL
        }
        components.path = credentials.baseURL.path + endpoint.path
        components.queryItems = endpoint.queryItems.isEmpty ? nil : endpoint.queryItems
        guard let url = components.url else { throw APIError.invalidBaseURL }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if endpoint.requiresAuthentication {
            request.setValue(credentials.apiKey, forHTTPHeaderField: "X-API-Key")
        }
        if let body = endpoint.body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if endpoint.path == "/events" {
            request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
            request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        }
        return request
    }

    private static func errorMessage(from data: Data) -> String? {
        guard !data.isEmpty,
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            let text = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : text
        }
        return (object["error"] as? String) ?? (object["message"] as? String)
    }
}
