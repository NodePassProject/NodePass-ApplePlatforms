//
//  MockMasterIntegrationTests.swift
//  NodePassTests
//
//  Exercises the live client and session against Scripts/mock_master.py when it is running on
//  127.0.0.1:9090. Skipped silently otherwise so the suite stays green on CI.
//

import Foundation
import Testing
@testable import NodePass

@MainActor
struct MockMasterIntegrationTests {
    private static let baseURL = URL(string: "http://127.0.0.1:9090/api/v1")!
    private static let credentials = MasterCredentials(baseURL: baseURL, apiKey: "demo", trustsSelfSignedCertificates: true)

    private static func mockIsReachable() async -> Bool {
        let client = MasterClient(credentials: credentials, requestTimeout: 1)
        return (try? await client.info()) != nil
    }

    @Test func clientStreamsEvents() async throws {
        guard await Self.mockIsReachable() else { return }
        let client = MasterClient(credentials: Self.credentials)
        // Race the stream against a timer so a silent stream fails instead of hanging the suite.
        let kinds: [InstanceEvent.Kind] = try await withThrowingTaskGroup(of: [InstanceEvent.Kind].self) { group in
            group.addTask {
                var collected: [InstanceEvent.Kind] = []
                for try await event in client.events() {
                    collected.append(event.kind)
                    if collected.count >= 6 { break }
                }
                return collected
            }
            group.addTask {
                try await Task.sleep(for: .seconds(8))
                return []
            }
            let first = try await group.next() ?? []
            group.cancelAll()
            return first
        }
        #expect(kinds.contains(.initial))
        #expect(kinds.count >= 6, "expected a steady stream of events, got \(kinds)")
    }

    @Test func sessionGoesLive() async throws {
        guard await Self.mockIsReachable() else { return }
        let snapshot = MasterSnapshot(id: "test", name: "Mock", url: Self.baseURL.absoluteString, key: "demo", isEnabled: true, timestamp: .now, trustsSelfSignedCertificates: true)
        let session = MasterSession(snapshot: snapshot, flavorOverride: nil)
        session.start()
        defer { session.stop() }
        var observed: [String] = []
        for _ in 0..<40 {
            observed.append(session.connection.title)
            if session.connection == .live { break }
            try await Task.sleep(for: .milliseconds(250))
        }
        #expect(session.connection == .live, "connection states: \(observed) lastError: \(String(describing: session.lastError))")
        #expect(!session.visibleInstances.isEmpty)
        #expect(session.flavor == .nodePass)
    }
}
