//
//  MasterSession.swift
//  NodePass
//
//  Live state of one master: instance table fed by SSE (with polling fallback),
//  periodic system info, per-instance logs and throughput samples.
//

import Foundation
import Observation
import OSLog

private let sessionLog = Logger(subsystem: "com.argsment.NodePass", category: "MasterSession")

enum ConnectionState: Hashable {
    case idle
    case connecting
    /// Receiving Server-Sent Events.
    case live
    /// SSE unavailable; instances are refreshed by polling.
    case polling
    case offline(String)

    var title: String {
        switch self {
        case .idle: "Idle"
        case .connecting: "Connecting"
        case .live: "Live"
        case .polling: "Polling"
        case .offline: "Offline"
        }
    }

    var isReachable: Bool {
        switch self {
        case .live, .polling: true
        default: false
        }
    }
}

struct BatchOutcome: Identifiable, Hashable {
    let instanceID: String
    let instanceName: String
    let error: String?

    var id: String { instanceID }
    var succeeded: Bool { error == nil }
}

struct InfoSample: Hashable, Identifiable {
    let date: Date
    let cpu: Double
    let memory: Double
    let networkReceiveRate: Double
    let networkTransmitRate: Double

    var id: Date { date }
}

@Observable
@MainActor
final class MasterSession: Identifiable {
    let id: String
    private(set) var snapshot: MasterSnapshot
    private(set) var client: MasterClient?
    private(set) var flavorOverride: MasterFlavor?

    private(set) var instances: [String: Instance] = [:]
    private(set) var info: MasterInfo?
    private(set) var infoError: APIError?
    private(set) var connection: ConnectionState = .idle
    private(set) var lastError: APIError?
    private(set) var lastEventDate: Date?
    private(set) var lastInstanceRefresh: Date?
    private(set) var hasLoadedInstances = false

    private(set) var logs: [String: LogBuffer] = [:]
    private(set) var rates: [String: TrafficRateTracker] = [:]
    private(set) var infoHistory: [InfoSample] = []

    /// Instance IDs with an operation in flight.
    private(set) var busyInstanceIDs: Set<String> = []

    var liveEventsEnabled: Bool = true
    var infoRefreshInterval: TimeInterval = NPCore.Defaults.infoRefreshInterval
    var instancePollInterval: TimeInterval = NPCore.Defaults.instancePollInterval
    var logCapacity: Int = NPCore.Defaults.logBufferSize

    private var eventTask: Task<Void, Never>?
    private var infoTask: Task<Void, Never>?
    private var pollTask: Task<Void, Never>?
    private var reconnectDelay: Duration = .seconds(2)
    private var lastInfoDate: Date?
    private var lastInfo: MasterInfo?

    init(snapshot: MasterSnapshot, flavorOverride: MasterFlavor?) {
        self.id = snapshot.id
        self.snapshot = snapshot
        self.flavorOverride = flavorOverride
        self.client = snapshot.credentials.map { MasterClient(credentials: $0) }
    }

    // MARK: Derived

    var displayName: String { snapshot.name }

    /// Effective API flavor: explicit setting, URL hint, or observed instance roles.
    var flavor: MasterFlavor {
        if let flavorOverride { return flavorOverride }
        if let credentials = snapshot.credentials, let inferred = MasterFlavor.infer(fromBaseURL: credentials.baseURL) {
            return inferred
        }
        return MasterFlavor.infer(fromRoles: instances.values.map(\.role)) ?? .nodePass
    }

    /// All managed instances, excluding the API-key holder.
    var visibleInstances: [Instance] {
        instances.values.filter { !$0.isAPIKeyHolder }
    }

    var apiKeyHolder: Instance? { instances[NPCore.apiKeyInstanceID] }

    var masterID: String {
        if let info, !info.masterID.isEmpty { return info.masterID }
        return apiKeyHolder?.config ?? ""
    }

    var runningCount: Int { visibleInstances.filter { $0.status == .running }.count }
    var stoppedCount: Int { visibleInstances.filter { $0.status == .stopped }.count }
    var errorCount: Int { visibleInstances.filter { $0.status == .error }.count }

    var totalReceived: UInt64 { visibleInstances.reduce(0) { $0 &+ $1.totalReceived } }
    var totalTransmitted: UInt64 { visibleInstances.reduce(0) { $0 &+ $1.totalTransmitted } }

    /// Aggregate throughput over the latest samples of every instance.
    var aggregateRate: (received: Double, transmitted: Double) {
        var rx = 0.0, tx = 0.0
        for tracker in rates.values {
            if let latest = tracker.latest, Date.now.timeIntervalSince(latest.date) < 15 {
                rx += latest.received
                tx += latest.transmitted
            }
        }
        return (rx, tx)
    }

    var networkRate: (received: Double, transmitted: Double)? {
        guard let sample = infoHistory.last, Date.now.timeIntervalSince(sample.date) < infoRefreshInterval * 3 else { return nil }
        return (sample.networkReceiveRate, sample.networkTransmitRate)
    }

    func instance(_ id: String) -> Instance? { instances[id] }
    func logBuffer(for id: String) -> LogBuffer { logs[id] ?? LogBuffer(capacity: logCapacity) }
    func rateTracker(for id: String) -> TrafficRateTracker { rates[id] ?? TrafficRateTracker() }
    func isBusy(_ id: String) -> Bool { busyInstanceIDs.contains(id) }

    // MARK: Lifecycle

    func update(snapshot: MasterSnapshot, flavorOverride: MasterFlavor?) {
        let credentialsChanged = snapshot.credentials != self.snapshot.credentials
        self.snapshot = snapshot
        self.flavorOverride = flavorOverride
        if credentialsChanged {
            let wasRunning = eventTask != nil || infoTask != nil
            stop()
            client = snapshot.credentials.map { MasterClient(credentials: $0) }
            instances.removeAll()
            info = nil
            infoHistory.removeAll()
            hasLoadedInstances = false
            if wasRunning, snapshot.isEnabled { start() }
        }
    }

    func start() {
        guard snapshot.isEnabled, client != nil else {
            connection = .idle
            return
        }
        sessionLog.debug("start \(self.snapshot.name, privacy: .public) live=\(self.liveEventsEnabled) eventTask=\(self.eventTask != nil) infoTask=\(self.infoTask != nil)")
        if infoTask == nil {
            infoTask = Task { [weak self] in await self?.runInfoLoop() }
        }
        if liveEventsEnabled {
            if eventTask == nil {
                connection = .connecting
                eventTask = Task { [weak self] in await self?.runEventLoop() }
            }
        } else {
            startPolling()
        }
    }

    func stop() {
        sessionLog.debug("stop \(self.snapshot.name, privacy: .public)")
        eventTask?.cancel()
        eventTask = nil
        infoTask?.cancel()
        infoTask = nil
        pollTask?.cancel()
        pollTask = nil
        connection = .idle
    }

    func apply(_ configuration: SessionConfiguration) {
        let liveChanged = configuration.liveEventsEnabled != liveEventsEnabled
        liveEventsEnabled = configuration.liveEventsEnabled
        infoRefreshInterval = configuration.infoRefreshInterval
        instancePollInterval = configuration.instancePollInterval
        logCapacity = configuration.logCapacity
        for key in logs.keys { logs[key]?.capacity = logCapacity }
        if liveChanged, eventTask != nil || pollTask != nil {
            stop()
            start()
        }
    }

    // MARK: Event loop

    private func runEventLoop() async {
        guard let client else { return }
        while !Task.isCancelled {
            connection = connection == .live ? .live : .connecting
            // Reconcile through REST on every (re)connect: the stream's `initial` burst has no
            // terminator, so this is what removes instances that vanished while we were away.
            Task { [weak self] in await self?.refreshInstances() }
            do {
                for try await event in client.events() {
                    if Task.isCancelled { break }
                    sessionLog.debug("event \(String(describing: event.kind), privacy: .public) for \(event.instance?.id ?? "-", privacy: .public)")
                    if connection != .live {
                        connection = .live
                        reconnectDelay = .seconds(2)
                        stopPolling()
                        lastError = nil
                    }
                    lastEventDate = event.time
                    switch event.kind {
                    case .initial, .create, .update:
                        if let instance = event.instance {
                            upsert(instance, at: event.time)
                            hasLoadedInstances = true
                        }
                    case .delete:
                        if let instance = event.instance { remove(instance.id) }
                    case .log:
                        if let instance = event.instance, !event.logs.isEmpty {
                            appendLog(event.logs, for: instance.id, at: event.time)
                        }
                    case .shutdown:
                        connection = .offline("Master is shutting down")
                    case .other:
                        break
                    }
                }
                if !Task.isCancelled, case .live = connection {
                    connection = .polling
                }
            } catch let error as APIError {
                lastError = error
                if error.isAuthenticationFailure {
                    connection = .offline(error.localizedDescription)
                    return
                }
                connection = .polling
            } catch {
                lastError = APIError.wrap(error)
                connection = .polling
            }
            if Task.isCancelled { return }
            // Keep polling until the stream returns.
            startPolling()
            try? await Task.sleep(for: reconnectDelay)
            reconnectDelay = min(reconnectDelay * 2, .seconds(30))
        }
    }

    private func startPolling() {
        guard pollTask == nil else { return }
        if connection != .live { connection = hasLoadedInstances || lastError == nil ? .polling : connection }
        pollTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(instancePollInterval))
                if Task.isCancelled { return }
                await refreshInstances()
            }
        }
    }

    private func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    private func runInfoLoop() async {
        while !Task.isCancelled {
            await refreshInfo()
            try? await Task.sleep(for: .seconds(infoRefreshInterval))
        }
    }

    // MARK: Refresh

    func refreshInstances() async {
        guard let client else { return }
        do {
            let fetched = try await client.instances()
            let now = Date.now
            var table: [String: Instance] = [:]
            for instance in fetched {
                table[instance.id] = instance
                feedRate(for: instance, at: now)
            }
            instances = table
            hasLoadedInstances = true
            lastInstanceRefresh = now
            lastError = nil
            if connection != .live { connection = .polling }
        } catch let error as APIError {
            lastError = error
            if !hasLoadedInstances || !connection.isReachable || error.isAuthenticationFailure {
                connection = .offline(error.shortDescription)
            } else if connection != .live {
                connection = .offline(error.shortDescription)
            }
        } catch {
            lastError = APIError.wrap(error)
            connection = .offline(APIError.wrap(error).shortDescription)
        }
    }

    func refreshInfo() async {
        guard let client else { return }
        do {
            let fetched = try await client.info()
            let now = Date.now
            var rx = 0.0, tx = 0.0
            if let lastInfo, let lastInfoDate {
                let elapsed = now.timeIntervalSince(lastInfoDate)
                if elapsed > 0 {
                    if fetched.networkReceived >= lastInfo.networkReceived { rx = Double(fetched.networkReceived - lastInfo.networkReceived) / elapsed }
                    if fetched.networkTransmitted >= lastInfo.networkTransmitted { tx = Double(fetched.networkTransmitted - lastInfo.networkTransmitted) / elapsed }
                }
            }
            info = fetched
            infoError = nil
            infoHistory.append(InfoSample(date: now, cpu: fetched.cpuRatio, memory: fetched.memoryRatio, networkReceiveRate: rx, networkTransmitRate: tx))
            if infoHistory.count > 120 { infoHistory.removeFirst(infoHistory.count - 120) }
            lastInfo = fetched
            lastInfoDate = now
            if case .offline = connection, lastError?.isAuthenticationFailure != true {
                // Master is reachable again; make sure the instance table recovers.
                await refreshInstances()
            }
        } catch let error as APIError {
            infoError = error
            if error.isAuthenticationFailure {
                connection = .offline(error.localizedDescription)
            }
        } catch {
            infoError = APIError.wrap(error)
        }
    }

    // MARK: Mutations

    @discardableResult
    func create(url: String, alias: String?) async throws -> Instance {
        guard let client else { throw APIError.invalidBaseURL }
        let created = try await client.createInstance(url: url, alias: alias)
        upsert(created, at: .now)
        return created
    }

    @discardableResult
    func replaceURL(_ url: String, for id: String) async throws -> Instance {
        guard let client else { throw APIError.invalidBaseURL }
        return try await tracking(id) {
            let updated = try await client.replaceInstanceURL(id: id, url: url)
            upsert(updated, at: .now)
            return updated
        }
    }

    @discardableResult
    func patch(_ patch: InstancePatch, for id: String) async throws -> Instance {
        guard let client else { throw APIError.invalidBaseURL }
        return try await tracking(id) {
            let updated = try await client.patchInstance(id: id, patch)
            upsert(updated, at: .now)
            return updated
        }
    }

    func perform(_ action: InstanceAction, on id: String) async throws {
        _ = try await patch(InstancePatch(action: action), for: id)
    }

    func delete(_ id: String) async throws {
        guard let client else { throw APIError.invalidBaseURL }
        try await tracking(id) {
            try await client.deleteInstance(id: id)
            remove(id)
        }
    }

    /// Runs one operation against many instances concurrently and reports per-instance outcomes.
    func batch(_ ids: [String], _ operation: @escaping @Sendable (MasterClient, String) async throws -> Void) async -> [BatchOutcome] {
        guard let client else { return ids.map { BatchOutcome(instanceID: $0, instanceName: $0, error: APIError.invalidBaseURL.localizedDescription) } }
        busyInstanceIDs.formUnion(ids)
        defer { busyInstanceIDs.subtract(ids) }
        var outcomes: [BatchOutcome] = []
        await withTaskGroup(of: BatchOutcome.self) { group in
            for id in ids {
                let name = instances[id]?.displayName ?? id
                group.addTask {
                    do {
                        try await operation(client, id)
                        return BatchOutcome(instanceID: id, instanceName: name, error: nil)
                    } catch {
                        return BatchOutcome(instanceID: id, instanceName: name, error: APIError.wrap(error).localizedDescription)
                    }
                }
            }
            for await outcome in group { outcomes.append(outcome) }
        }
        await refreshInstances()
        return outcomes.sorted { $0.instanceName.localizedStandardCompare($1.instanceName) == .orderedAscending }
    }

    func updateMasterAlias(_ alias: String) async throws {
        guard let client else { throw APIError.invalidBaseURL }
        info = try await client.updateMasterAlias(alias)
    }

    /// Rotates the API key on the master and returns the new key.
    func regenerateAPIKey() async throws -> String {
        guard let client else { throw APIError.invalidBaseURL }
        return try await client.regenerateAPIKey()
    }

    func tcping(_ target: String) async throws -> TCPingResult {
        guard let client else { throw APIError.invalidBaseURL }
        return try await client.tcping(target: target)
    }

    func clearLogs(for id: String) {
        logs[id]?.clear()
    }

    // MARK: Table maintenance

    private func upsert(_ instance: Instance, at date: Date) {
        instances[instance.id] = instance
        feedRate(for: instance, at: date)
    }

    private func remove(_ id: String) {
        instances.removeValue(forKey: id)
        rates.removeValue(forKey: id)
    }

    private func feedRate(for instance: Instance, at date: Date) {
        guard !instance.isAPIKeyHolder else { return }
        var tracker = rates[instance.id] ?? TrafficRateTracker()
        tracker.record(received: instance.totalReceived, transmitted: instance.totalTransmitted, at: date)
        rates[instance.id] = tracker
    }

    private func appendLog(_ text: String, for id: String, at date: Date) {
        var buffer = logs[id] ?? LogBuffer(capacity: logCapacity)
        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: true) {
            buffer.append(LogLine(date: date, rawText: String(rawLine)))
        }
        logs[id] = buffer
    }

    private func tracking<T>(_ id: String, _ body: () async throws -> T) async throws -> T {
        busyInstanceIDs.insert(id)
        defer { busyInstanceIDs.remove(id) }
        return try await body()
    }
}
