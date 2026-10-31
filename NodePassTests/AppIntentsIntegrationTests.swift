//
//  AppIntentsIntegrationTests.swift
//  NodePassTests
//
//  Runs the intents' model against Scripts/mock_master.py on 127.0.0.1:9090: master health,
//  instance lookup, the control actions, instance creation and TCP ping, with no live session,
//  which is how Siri and Shortcuts run intents in the background. Skipped silently when the mock
//  is not up.
//
//  The intents themselves are thin wrappers whose `@Dependency` values exist only inside the
//  App Intents runtime, so the tests drive `IntentModel` directly.
//

import AppIntents
import Foundation
import SwiftData
import Testing
@testable import NodePass

@MainActor
@Suite(.serialized)
struct AppIntentsIntegrationTests {
    private static let baseURL = "http://127.0.0.1:9090/api/v1"
    private static let credentials = MasterCredentials(baseURL: URL(string: baseURL)!, apiKey: "demo", trustsSelfSignedCertificates: true)

    private struct Environment {
        let model: IntentModel
        let master: MasterSnapshot
        var entity: MasterEntity { MasterEntity(master) }
    }

    private static func environmentIfMockIsUp() async throws -> Environment? {
        let client = MasterClient(credentials: credentials, requestTimeout: 1)
        guard (try? await client.info()) != nil else { return nil }
        let container = try NPData.makeContainer(inMemory: true)
        let record = Server(name: "Mock Lab", url: baseURL, key: "demo")
        container.mainContext.insert(record)
        try container.mainContext.save()
        let store = MasterStore(container: container)
        return Environment(model: IntentModel(masters: store, sessions: SessionStore()), master: record.snapshot)
    }

    @Test func modelListsInstancesOfEnabledMasters() async throws {
        guard let env = try await Self.environmentIfMockIsUp() else { return }

        #expect(try env.model.master(env.master.id).name == "Mock Lab")
        #expect(throws: NodePassIntentError.self) { try env.model.master("missing") }

        let entities = try await env.model.instanceEntities()
        #expect(!entities.isEmpty)
        #expect(!entities.contains { $0.identifier == NPCore.apiKeyInstanceID }, "the key holder is never an entity")
        #expect(entities.allSatisfy { $0.master.id == env.master.id })
        #expect(entities.contains { $0.name == "edge-tokyo" && $0.status == .running })

        let first = try #require(entities.first)
        let refreshed = try await env.model.refreshed(first)
        #expect(refreshed.id == first.id)
        #expect(refreshed.name == first.name)

        await #expect(throws: NodePassIntentError.self) {
            _ = try await env.model.instance("does-not-exist", of: env.master)
        }
        await #expect(throws: NodePassIntentError.self) {
            _ = try await env.model.instance(NPCore.apiKeyInstanceID, of: env.master)
        }
    }

    @Test func masterHealthReportsTheMock() async throws {
        guard let env = try await Self.environmentIfMockIsUp() else { return }

        let health = await env.model.health(of: env.master)
        #expect(health.isReachable)
        #expect(health.info?.version == "mock-1.9.0")
        #expect(health.runningCount >= 1)
        #expect(!health.instances.contains { $0.isAPIKeyHolder })

        let report = MasterStatus.Report(master: env.entity, health: health)
        #expect(report.isReachable)
        #expect(report.version == "mock-1.9.0")
        #expect(report.cpuUsage != nil)
        let status = MasterStatus(report)
        #expect(status.master?.id == env.master.id)
        #expect(status.runningCount == health.runningCount)

        var unreachable = env.master
        unreachable = MasterSnapshot(id: unreachable.id, name: unreachable.name, url: "http://127.0.0.1:1/api/v1", key: "demo",
                                     isEnabled: true, timestamp: .now, trustsSelfSignedCertificates: true, flavor: .nodePass)
        let down = await env.model.health(of: unreachable)
        #expect(!down.isReachable)
        #expect(down.failure?.isEmpty == false)
    }

    @Test func instanceLifecycleThroughTheModel() async throws {
        guard let env = try await Self.environmentIfMockIsUp() else { return }

        let parsed = try CreateInstanceIntent.validate(url: "server://:19999/127.0.0.1:18080?tls=0", for: env.master)
        let created = try await env.model.create(url: parsed.description, alias: "intent-test", on: env.master)
        #expect(created.alias == "intent-test")
        #expect(created.status == .stopped)

        let entity = InstanceEntity(created, master: env.entity)
        #expect(entity.id == InstanceEntity.ID(masterID: env.master.id, instanceID: created.id))

        let started = try await env.model.perform(.start, on: created.id, of: env.master)
        #expect(started.status == .running)
        #expect(!InstanceAction.start.isApplicable(to: started.status), "a second start is answered without touching the master")

        let fresh = try await env.model.refreshed(entity)
        #expect(fresh.status == .running)
        #expect(String(localized: GetInstanceStatusIntent.statusText(for: fresh)).hasPrefix("intent-test is running"))

        let withoutRestart = try await env.model.setRestartPolicy(false, on: created.id, of: env.master)
        #expect(!withoutRestart.restart)

        let stopped = try await env.model.perform(.stop, on: created.id, of: env.master)
        #expect(stopped.status == .stopped)

        let restarted = try await env.model.perform(.restart, on: created.id, of: env.master)
        #expect(restarted.status == .running)

        let reset = try await env.model.perform(.reset, on: created.id, of: env.master)
        #expect(reset.totalTraffic == 0)

        try await env.model.delete(created.id, of: env.master)
        await #expect(throws: NodePassIntentError.self) {
            _ = try await env.model.instance(created.id, of: env.master)
        }
    }

    @Test func masterRejectionsBecomeIntentErrors() async throws {
        guard let env = try await Self.environmentIfMockIsUp() else { return }

        // The URL parses, so it reaches the master, which rejects the scheme with a 400.
        await #expect(throws: NodePassIntentError.self) {
            _ = try await env.model.create(url: "relay://:1/127.0.0.1:2", alias: nil, on: env.master)
        }
        #expect(throws: NodePassIntentError.self) {
            _ = try CreateInstanceIntent.validate(url: "portal://0123456789abcdef0123456789abcdef@*/tcp:7001", for: env.master)
        }
    }

    @Test func tcpingAnswersThroughTheMaster() async throws {
        guard let env = try await Self.environmentIfMockIsUp() else { return }

        let target = try #require(TCPingIntent.normalizedTarget(" 127.0.0.1:9090 "))
        let outcome = TCPingResultEntity.Outcome(try await env.model.tcping(target, from: env.master), target: target, master: env.entity)
        #expect(outcome.target == "127.0.0.1:9090")
        #expect(outcome.master.id == env.master.id)
        #expect(outcome.isConnected == (outcome.latency != nil))
        let entity = TCPingResultEntity(outcome)
        #expect(entity.target == "127.0.0.1:9090")
        #expect(entity.isConnected == outcome.isConnected)
    }
}
