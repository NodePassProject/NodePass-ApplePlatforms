//
//  AppIntentsTests.swift
//  NodePassTests
//
//  The parts of the App Intents layer that need no master: identifiers, value mapping, dialogs,
//  URL validation and the master store.
//

import AppIntents
import Foundation
import SwiftData
import Testing
@testable import NodePass

@MainActor
struct AppIntentsTests {
    private static let master = MasterSnapshot(
        id: "9B1DEB4D-3B7D-4BAD-9BDD-2B0D7B3DCB6D", name: "Home Lab", url: "http://127.0.0.1:9090/api/v1", key: "demo",
        isEnabled: true, timestamp: .now, trustsSelfSignedCertificates: true, flavor: .nodePass
    )

    private static func instance(status: InstanceStatus = .running) -> Instance {
        var instance = Instance(id: "a1b2c3d4")
        instance.alias = "edge-tunnel"
        instance.role = .server
        instance.status = status
        instance.url = "server://:10101/127.0.0.1:8080?tls=1"
        instance.restart = true
        instance.tcpConnections = 3
        instance.udpConnections = 1
        instance.tcpReceived = 2_048
        instance.tcpTransmitted = 1_024
        instance.ping = 12
        instance.meta.tags = ["env": "prod", "pinned": ""]
        return instance
    }

    // MARK: Identifiers

    @Test func instanceIdentifiersRoundTrip() {
        let id = InstanceEntity.ID(masterID: Self.master.id, instanceID: "a1b2c3d4")
        let string = id.entityIdentifierString
        #expect(string == "\(Self.master.id)/a1b2c3d4")
        #expect(InstanceEntity.ID.entityIdentifier(for: string) == id)
    }

    @Test func instanceIdentifiersSplitOnTheFirstSlashOnly() {
        let id = InstanceEntity.ID.entityIdentifier(for: "master/with/slashes")
        #expect(id?.masterID == "master")
        #expect(id?.instanceID == "with/slashes")
        #expect(InstanceEntity.ID.entityIdentifier(for: "no-slash") == nil)
        #expect(InstanceEntity.ID.entityIdentifier(for: "/orphan") == nil)
        #expect(InstanceEntity.ID.entityIdentifier(for: "master/") == nil)
    }

    // MARK: Entities

    @Test func masterEntityExposesTheRecordWithoutItsKey() {
        let entity = MasterEntity(Self.master)
        #expect(entity.id == Self.master.id)
        #expect(entity.name == "Home Lab")
        #expect(entity.host == "127.0.0.1")
        #expect(entity.apiURL?.absoluteString == "http://127.0.0.1:9090/api/v1")
        #expect(entity.flavor == .nodePass)
        #expect(entity.isEnabled)
        #expect(!entity.summaryText.contains("demo"))
    }

    @Test func instanceEntityMirrorsTheWireRecord() {
        let entity = InstanceEntity(Self.instance(), master: MasterEntity(Self.master))
        #expect(entity.id == InstanceEntity.ID(masterID: Self.master.id, instanceID: "a1b2c3d4"))
        #expect(entity.name == "edge-tunnel")
        #expect(entity.identifier == "a1b2c3d4")
        #expect(entity.master.name == "Home Lab")
        #expect(entity.role == .server)
        #expect(entity.status == .running)
        #expect(entity.endpoint == ":10101 → 127.0.0.1:8080")
        #expect(entity.autoRestart)
        #expect(entity.tcpConnections == 3)
        #expect(entity.udpConnections == 1)
        #expect(entity.bytesReceived == 2_048)
        #expect(entity.bytesTransmitted == 1_024)
        #expect(entity.latency?.converted(to: .milliseconds).value == 12)
        #expect(entity.tags == ["env=prod", "pinned"])
        #expect(!entity.summaryText.contains("server://"), "the summary shows the endpoint, never the URL with its credential")
    }

    @Test func statusAndRoleKindsFoldUnknownValues() {
        #expect(InstanceStatusKind(.running) == .running)
        #expect(InstanceStatusKind(.other("paused")) == .unknown)
        #expect(InstanceStatusKind.error.status == .error)
        #expect(InstanceRoleKind(.portal) == .portal)
        #expect(InstanceRoleKind(.other("relay")) == .other)
        #expect(InstanceRoleKind.other.title == "Other")
        #expect(InstanceRoleKind.vector.title == "Vector")
    }

    @Test func masterStatusSummarizesHealth() {
        var info = MasterInfo()
        info.version = "1.9.0"
        info.hostname = "lab"
        info.cpuUsage = 23
        info.memoryTotal = 1_000
        info.memoryUsed = 480
        info.uptime = 3_600
        var health = MasterHealth(master: Self.master)
        health.info = info
        health.instances = [Self.instance(), Self.instance(status: .stopped), Self.instance(status: .error)]
        let report = MasterStatus.Report(master: MasterEntity(Self.master), health: health)
        #expect(report.isReachable)
        #expect(report.runningCount == 1 && report.stoppedCount == 1 && report.errorCount == 1)
        #expect(report.cpuUsage == 23)
        #expect(report.memoryUsage == 48)
        #expect(report.uptime?.converted(to: .seconds).value == 3_600)
        #expect(report.summary == "1 running · 1 stopped · 1 in error")

        let status = MasterStatus(report)
        #expect(status.master?.id == Self.master.id)
        #expect(status.errorCount == 1)

        var down = MasterHealth(master: Self.master)
        down.failure = "Unauthorized"
        let downReport = MasterStatus.Report(master: MasterEntity(Self.master), health: down)
        #expect(!downReport.isReachable)
        #expect(downReport.summary == "Unauthorized")
        #expect(downReport.symbolName == "bolt.horizontal.circle")
    }

    @Test func tcpingOutcomeDescribesBothResults() {
        let master = MasterEntity(Self.master)
        let ok = TCPingResultEntity.Outcome(TCPingResult(target: "1.1.1.1:443", connected: true, latency: 23), target: "1.1.1.1:443", master: master)
        #expect(ok.isConnected)
        #expect(ok.latencyText == "23 ms")
        #expect(ok.summary == "23 ms from Home Lab")
        let failed = TCPingResultEntity.Outcome(TCPingResult(target: "", connected: false, error: "connection refused"), target: "10.0.0.1:22", master: master)
        #expect(!failed.isConnected)
        #expect(failed.target == "10.0.0.1:22")
        #expect(failed.latency == nil)
        #expect(failed.summary == "connection refused")
    }

    // MARK: Validation

    @Test func createIntentValidatesURLsAgainstTheMaster() throws {
        let parsed = try CreateInstanceIntent.validate(url: "server://:10101/127.0.0.1:8080?tls=1", for: Self.master)
        #expect(parsed.role == .server)

        #expect(throws: NodePassIntentError.self) {
            try CreateInstanceIntent.validate(url: "not a url", for: Self.master)
        }
        #expect(throws: NodePassIntentError.self) {
            try CreateInstanceIntent.validate(url: "portal://0123456789abcdef0123456789abcdef@*/tcp:7001", for: Self.master)
        }
        var unknownFlavor = Self.master
        unknownFlavor.flavor = nil
        let portal = try CreateInstanceIntent.validate(url: "portal://0123456789abcdef0123456789abcdef@*/tcp:7001", for: unknownFlavor)
        #expect(portal.role == .portal)
    }

    @Test func tcpingTargetsNeedAPort() {
        #expect(TCPingIntent.normalizedTarget(" example.com:443 ") == "example.com:443")
        #expect(TCPingIntent.normalizedTarget("[2001:db8::1]:22") == "[2001:db8::1]:22")
        #expect(TCPingIntent.normalizedTarget("example.com") == nil)
        #expect(TCPingIntent.normalizedTarget("example.com:70000") == nil)
        #expect(TCPingIntent.normalizedTarget("") == nil)
    }

    // MARK: Errors

    @Test func intentErrorsWrapAPIErrorsForPeople() {
        #expect(matches(NodePassIntentError.wrap(APIError.notFound, master: Self.master), .instanceNotFound))
        if case .masterRejected(let master, _) = NodePassIntentError.wrap(APIError.badRequest("bad scheme"), master: Self.master) {
            #expect(master == "Home Lab")
        } else {
            Issue.record("expected masterRejected")
        }
        if case .masterUnreachable(let master, let reason) = NodePassIntentError.wrap(APIError.transport("timed out"), master: Self.master) {
            #expect(master == "Home Lab")
            #expect(reason == "timed out")
        } else {
            Issue.record("expected masterUnreachable")
        }
        let text = String(localized: NodePassIntentError.masterUnreachable(master: "Home Lab", reason: "timed out").localizedStringResource)
        #expect(text == "Home Lab is unreachable: timed out")
    }

    private func matches(_ error: NodePassIntentError, _ expected: NodePassIntentError) -> Bool {
        String(describing: error) == String(describing: expected)
    }

    // MARK: Store and navigation

    @Test func masterStoreReadsSnapshotsFromTheContainer() throws {
        let container = try NPData.makeContainer(inMemory: true)
        let first = Server(name: "Alpha", url: "https://alpha.example.com/api/v1", key: "k1")
        first.timestamp = Date(timeIntervalSince1970: 1)
        let second = Server(name: "Beta", url: "https://beta.example.com/api/v2", key: "k2", isEnabled: false)
        second.timestamp = Date(timeIntervalSince1970: 2)
        container.mainContext.insert(first)
        container.mainContext.insert(second)
        try container.mainContext.save()

        let store = MasterStore(container: container)
        let snapshots = try store.snapshots()
        #expect(snapshots.map(\.name) == ["Alpha", "Beta"])
        #expect(snapshots[0].flavor == .nodePass)
        #expect(snapshots[1].flavor == .openCtrl)
        #expect(try store.snapshots(ids: [second.id, "missing", first.id]).map(\.name) == ["Beta", "Alpha"])
        #expect(try store.snapshot(id: "missing") == nil)
    }

    @Test func toolDeepLinksSelectTheTool() {
        let model = NavigationModel()
        model.handle(deepLink: DeepLink.tool(Tool.apiConsole.rawValue))
        #expect(model.sidebarSelection == .tool(.apiConsole))
        model.handle(deepLink: DeepLink.tool("nonsense"))
        #expect(model.sidebarSelection == .tool(.apiConsole))
    }

    @Test func dialogsNameTheInstanceAndOutcome() {
        let entity = InstanceEntity(Self.instance(), master: MasterEntity(Self.master))
        #expect(String(localized: InstanceControl.unchangedText(.start, entity)) == "edge-tunnel is already running.")
        #expect(String(localized: InstanceControl.completionText(.restart, entity)) == "Restarted edge-tunnel.")
        #expect(String(localized: GetInstanceStatusIntent.statusText(for: entity)) == "edge-tunnel is running with 3 TCP and 1 UDP connections.")
        let stopped = InstanceEntity(Self.instance(status: .stopped), master: MasterEntity(Self.master))
        #expect(String(localized: GetInstanceStatusIntent.statusText(for: stopped)) == "edge-tunnel is stopped.")
    }
}
