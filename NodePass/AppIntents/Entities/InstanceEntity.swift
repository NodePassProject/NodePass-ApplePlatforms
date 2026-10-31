//
//  InstanceEntity.swift
//  NodePass
//
//  A managed instance as an App Intents entity. Instances are identified per master, so the
//  entity's identifier carries both; the system stores only that identifier and asks
//  `InstanceQuery` for everything else, which keeps status and counters fresh.
//

import AppIntents
import Foundation

nonisolated struct InstanceEntity: AppEntity {
    /// `<master id>/<instance id>`. Master identifiers are UUIDs and never contain a slash.
    nonisolated struct ID: Hashable, Sendable, EntityIdentifierConvertible {
        let masterID: String
        let instanceID: String

        var entityIdentifierString: String { "\(masterID)/\(instanceID)" }

        static func entityIdentifier(for entityIdentifierString: String) -> ID? {
            guard let slash = entityIdentifierString.firstIndex(of: "/") else { return nil }
            let masterID = String(entityIdentifierString[..<slash])
            let instanceID = String(entityIdentifierString[entityIdentifierString.index(after: slash)...])
            guard !masterID.isEmpty, !instanceID.isEmpty else { return nil }
            return ID(masterID: masterID, instanceID: instanceID)
        }
    }

    static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: "Instance",
        numericFormat: "\(placeholder: .int) instances"
    )

    static let defaultQuery = InstanceQuery()

    /// User activity type advertised while an instance is on screen.
    static let viewingActivityType = "com.argsment.NodePass.viewingInstance"

    let id: ID

    /// The wire record this entity was made from, for snippets and dialogs.
    let instance: Instance

    private let owner: MasterEntity

    @ComputedProperty(title: "Name")
    var name: String { instance.displayName }

    @ComputedProperty(title: "Identifier")
    var identifier: String { instance.id }

    @ComputedProperty(title: "Master")
    var master: MasterEntity { owner }

    @ComputedProperty(title: "Type")
    var role: InstanceRoleKind { InstanceRoleKind(instance.role) }

    @ComputedProperty(title: "Status")
    var status: InstanceStatusKind { InstanceStatusKind(instance.status) }

    @ComputedProperty(title: "URL")
    var url: String { instance.url }

    @ComputedProperty(title: "Endpoint")
    var endpoint: String { instance.endpointSummary }

    @ComputedProperty(title: "Auto-restart")
    var autoRestart: Bool { instance.restart }

    @ComputedProperty(title: "TCP Connections")
    var tcpConnections: Int { instance.tcpConnections }

    @ComputedProperty(title: "UDP Connections")
    var udpConnections: Int { instance.udpConnections }

    @ComputedProperty(title: "Bytes Received")
    var bytesReceived: Int { Int(clamping: instance.totalReceived) }

    @ComputedProperty(title: "Bytes Transmitted")
    var bytesTransmitted: Int { Int(clamping: instance.totalTransmitted) }

    @ComputedProperty(title: "Latency")
    var latency: Measurement<UnitDuration>? {
        instance.ping > 0 ? Measurement(value: Double(instance.ping), unit: .milliseconds) : nil
    }

    /// `key=value` pairs, or the bare key for a tag without a value.
    @ComputedProperty(title: "Tags")
    var tags: [String] {
        instance.meta.sortedTags.map { $0.value.isEmpty ? $0.key : "\($0.key)=\($0.value)" }
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(name)",
            subtitle: "\(master.name) · \(status.title) · \(endpoint)",
            image: .init(systemName: status.symbolName)
        )
    }

    init(_ instance: Instance, master: MasterEntity) {
        id = ID(masterID: master.id, instanceID: instance.id)
        self.instance = instance
        owner = master
    }
}

struct InstanceQuery: nonisolated EntityQuery, nonisolated EntityStringQuery, nonisolated EnumerableEntityQuery {
    @Dependency private var model: IntentModel

    nonisolated init() {}

    @MainActor
    func entities(for identifiers: [InstanceEntity.ID]) async throws -> [InstanceEntity] {
        var found: [InstanceEntity.ID: InstanceEntity] = [:]
        for (masterID, ids) in Dictionary(grouping: identifiers, by: \.masterID) {
            // A master that was deleted makes its instances unresolvable, not the intent fail.
            guard let snapshot = try? model.master(masterID) else { continue }
            let master = MasterEntity(snapshot)
            if ids.count == 1, let id = ids.first {
                do {
                    found[id] = InstanceEntity(try await model.instance(id.instanceID, of: snapshot), master: master)
                } catch NodePassIntentError.instanceNotFound {
                    continue
                }
            } else {
                let wanted = Set(ids.map(\.instanceID))
                for instance in try await model.instances(of: snapshot) where wanted.contains(instance.id) {
                    found[InstanceEntity.ID(masterID: masterID, instanceID: instance.id)] = InstanceEntity(instance, master: master)
                }
            }
        }
        return identifiers.compactMap { found[$0] }
    }

    @MainActor
    func entities(matching string: String) async throws -> [InstanceEntity] {
        try await model.instanceEntities().filter { entity in
            entity.name.localizedCaseInsensitiveContains(string)
                || entity.identifier.localizedCaseInsensitiveContains(string)
                || entity.master.name.localizedCaseInsensitiveContains(string)
                || entity.endpoint.localizedCaseInsensitiveContains(string)
                || entity.tags.contains { $0.localizedCaseInsensitiveContains(string) }
        }
    }

    @MainActor
    func allEntities() async throws -> [InstanceEntity] {
        try await model.instanceEntities()
    }

    /// Instances worth offering first; Siri also learns their names from this list.
    @MainActor
    func suggestedEntities() async throws -> [InstanceEntity] {
        Array(try await model.instanceEntities().prefix(60))
    }

    nonisolated static var findIntentDescription: IntentDescription? {
        IntentDescription("Finds instances across your masters by name, status, type, endpoint or tag.", categoryName: "Instances")
    }
}
