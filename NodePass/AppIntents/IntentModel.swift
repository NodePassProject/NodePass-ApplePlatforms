//
//  IntentModel.swift
//  NodePass
//
//  What App Intents act on. Masters come from the persisted store. Instances come from the live
//  session while the app is running and connected, and straight from the master's API otherwise:
//  Siri and Shortcuts run intents in the background, where no session streams.
//

import Foundation

/// One master's answer to `/info` and `/instances`, or why it did not answer.
nonisolated struct MasterHealth: Sendable {
    let master: MasterSnapshot
    var info: MasterInfo?
    /// Managed instances, without the API-key holder.
    var instances: [Instance] = []
    var failure: String?

    var isReachable: Bool { failure == nil }
    var runningCount: Int { instances.filter { $0.status == .running }.count }
    var stoppedCount: Int { instances.filter { $0.status == .stopped }.count }
    var errorCount: Int { instances.filter { $0.status == .error }.count }
}

@MainActor
final class IntentModel {
    /// The persisted masters, shared with `MasterQuery`.
    let masters: MasterStore

    private let sessions: SessionStore
    private var clients: [String: MasterClient] = [:]
    /// Answers from moments ago, so a snippet rendered right after an intent does not ask again.
    private var recentHealth: [String: (date: Date, health: MasterHealth)] = [:]
    private var recentInstances: [InstanceEntity.ID: (date: Date, instance: Instance)] = [:]

    /// Siri waits for the answer, so requests give up sooner than in the app.
    private static let requestTimeout: TimeInterval = 8

    init(masters: MasterStore, sessions: SessionStore) {
        self.masters = masters
        self.sessions = sessions
    }

    // MARK: Masters

    func master(_ id: String) throws -> MasterSnapshot {
        guard let snapshot = try masters.snapshot(id: id) else { throw NodePassIntentError.masterNotFound }
        return snapshot
    }

    func master(for entity: MasterEntity) throws -> MasterSnapshot {
        try master(entity.id)
    }

    /// `/info` and `/instances` of a master. Takes the live session's data when the app is
    /// connected; an answer younger than `maxAge` is reused.
    func health(of master: MasterSnapshot, maxAge: TimeInterval = 0) async -> MasterHealth {
        if maxAge > 0, let recent = recentHealth[master.id], Date.now.timeIntervalSince(recent.date) < maxAge {
            return recent.health
        }
        var health = MasterHealth(master: master)
        if let session = loadedSession(for: master) {
            health.instances = session.visibleInstances
            if let info = session.info {
                health.info = info
            } else {
                health.info = try? await client(for: master).info()
            }
        } else {
            do {
                let client = try client(for: master)
                async let info = client.info()
                async let instances = client.instances()
                health.info = try await info
                health.instances = ((try? await instances) ?? []).filter { !$0.isAPIKeyHolder }
            } catch let error as NodePassIntentError {
                health.failure = String(localized: error.localizedStringResource)
            } catch {
                health.failure = APIError.wrap(error).localizedDescription
            }
        }
        for instance in health.instances { remember(instance, of: master) }
        recentHealth[master.id] = (.now, health)
        return health
    }

    // MARK: Instances

    /// The managed instances of a master, without the API-key holder.
    func instances(of master: MasterSnapshot) async throws -> [Instance] {
        let instances: [Instance]
        if let session = loadedSession(for: master) {
            instances = session.visibleInstances
        } else {
            do {
                instances = try await client(for: master).instances().filter { !$0.isAPIKeyHolder }
            } catch {
                throw NodePassIntentError.wrap(error, master: master)
            }
        }
        for instance in instances { remember(instance, of: master) }
        return instances
    }

    /// One instance of a master. An answer younger than `maxAge` is reused.
    func instance(_ id: String, of master: MasterSnapshot, maxAge: TimeInterval = 0) async throws -> Instance {
        // The key holder's `url` is the master's API key; it is never an entity.
        guard id != NPCore.apiKeyInstanceID else { throw NodePassIntentError.instanceNotFound }
        let key = InstanceEntity.ID(masterID: master.id, instanceID: id)
        if maxAge > 0, let recent = recentInstances[key], Date.now.timeIntervalSince(recent.date) < maxAge {
            return recent.instance
        }
        if let session = loadedSession(for: master) {
            guard let instance = session.instance(id) else { throw NodePassIntentError.instanceNotFound }
            remember(instance, of: master)
            return instance
        }
        do {
            let instance = try await client(for: master).instance(id: id)
            remember(instance, of: master)
            return instance
        } catch {
            throw NodePassIntentError.wrap(error, master: master)
        }
    }

    /// The entity again, with the instance as the master reports it now.
    func refreshed(_ entity: InstanceEntity, maxAge: TimeInterval = 0) async throws -> InstanceEntity {
        let master = try master(entity.id.masterID)
        let instance = try await instance(entity.id.instanceID, of: master, maxAge: maxAge)
        return InstanceEntity(instance, master: MasterEntity(master))
    }

    /// The instances of every enabled master, fetched concurrently and kept in master order. A
    /// master that does not answer contributes nothing rather than failing the whole list.
    func instancesOfEnabledMasters() async throws -> [(master: MasterSnapshot, instances: [Instance])] {
        let enabled = try masters.snapshots().filter(\.isEnabled)
        return await withTaskGroup(of: (Int, [Instance]).self) { group in
            for (index, master) in enabled.enumerated() {
                group.addTask { (index, (try? await self.instances(of: master)) ?? []) }
            }
            var results: [(Int, [Instance])] = []
            for await result in group { results.append(result) }
            return results.sorted { $0.0 < $1.0 }.map { (enabled[$0.0], $0.1) }
        }
    }

    /// Every instance as an entity, errors first, then running instances, then the rest by name.
    func instanceEntities() async throws -> [InstanceEntity] {
        func rank(_ status: InstanceStatus) -> Int {
            switch status {
            case .error: 0
            case .running: 1
            default: 2
            }
        }
        let entities = try await instancesOfEnabledMasters().flatMap { group in
            let master = MasterEntity(group.master)
            return group.instances.map { InstanceEntity($0, master: master) }
        }
        return entities.sorted { lhs, rhs in
            let l = rank(lhs.instance.status), r = rank(rhs.instance.status)
            if l != r { return l < r }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    // MARK: Mutations

    func perform(_ action: InstanceAction, on id: String, of master: MasterSnapshot) async throws -> Instance {
        var result = try await mutate(master) { session in
            try await session.patch(InstancePatch(action: action), for: id)
        } client: { client in
            try await client.perform(action, on: id)
        }
        // Masters apply start, stop and restart asynchronously. Give them a moment, so the answer
        // and the snippet describe the new state rather than the one just left behind.
        if let settled = action.settledStatus, result.status != settled {
            for _ in 0..<5 {
                try? await Task.sleep(for: .milliseconds(500))
                guard let current = try? await instance(id, of: master) else { break }
                result = current
                if current.status == settled { break }
            }
        }
        return result
    }

    func setRestartPolicy(_ enabled: Bool, on id: String, of master: MasterSnapshot) async throws -> Instance {
        try await mutate(master) { session in
            try await session.patch(InstancePatch(restart: enabled), for: id)
        } client: { client in
            try await client.setRestartPolicy(enabled, for: id)
        }
    }

    func create(url: String, alias: String?, on master: MasterSnapshot) async throws -> Instance {
        try await mutate(master) { session in
            try await session.create(url: url, alias: alias)
        } client: { client in
            try await client.createInstance(url: url, alias: alias)
        }
    }

    func delete(_ id: String, of master: MasterSnapshot) async throws {
        do {
            if let session = connectedSession(for: master) {
                try await session.delete(id)
            } else {
                try await client(for: master).deleteInstance(id: id)
                if let session = sessions.session(for: master.id) {
                    Task { await session.refreshInstances() }
                }
            }
        } catch {
            throw NodePassIntentError.wrap(error, master: master)
        }
        recentInstances.removeValue(forKey: InstanceEntity.ID(masterID: master.id, instanceID: id))
        recentHealth.removeValue(forKey: master.id)
    }

    func tcping(_ target: String, from master: MasterSnapshot) async throws -> TCPingResult {
        do {
            return try await client(for: master).tcping(target: target)
        } catch {
            throw NodePassIntentError.wrap(error, master: master)
        }
    }

    // MARK: Plumbing

    /// Runs a change through the live session when the app is connected, so the UI reflects it at
    /// once, and through a client of our own otherwise.
    private func mutate(_ master: MasterSnapshot,
                        session sessionWork: (MasterSession) async throws -> Instance,
                        client clientWork: (MasterClient) async throws -> Instance) async throws -> Instance {
        let instance: Instance
        do {
            if let session = connectedSession(for: master) {
                instance = try await sessionWork(session)
            } else {
                instance = try await clientWork(try client(for: master))
                // A session that exists but is between reconnects catches up right away.
                if let session = sessions.session(for: master.id) {
                    Task { await session.refreshInstances() }
                }
            }
        } catch {
            throw NodePassIntentError.wrap(error, master: master)
        }
        remember(instance, of: master)
        recentHealth.removeValue(forKey: master.id)
        return instance
    }

    /// The master's session when it is reachable right now.
    private func connectedSession(for master: MasterSnapshot) -> MasterSession? {
        guard let session = sessions.session(for: master.id), session.client != nil, session.connection.isReachable else { return nil }
        return session
    }

    /// The master's session when its instance table is current.
    private func loadedSession(for master: MasterSnapshot) -> MasterSession? {
        guard let session = connectedSession(for: master), session.hasLoadedInstances else { return nil }
        return session
    }

    private func client(for master: MasterSnapshot) throws -> MasterClient {
        guard let credentials = master.credentials else { throw NodePassIntentError.invalidMasterURL(master: master.name) }
        if let client = clients[master.id], client.credentials == credentials { return client }
        let client = MasterClient(credentials: credentials, requestTimeout: Self.requestTimeout)
        clients[master.id] = client
        return client
    }

    private func remember(_ instance: Instance, of master: MasterSnapshot) {
        recentInstances[InstanceEntity.ID(masterID: master.id, instanceID: instance.id)] = (.now, instance)
    }
}

private extension InstanceAction {
    /// The status the master reports once the action has taken effect, for actions that change it.
    var settledStatus: InstanceStatus? {
        switch self {
        case .start, .restart: .running
        case .stop: .stopped
        case .reset: nil
        }
    }
}
