//
//  MasterReport.swift
//  NodePass Widget
//
//  Everything a widget shows about one master, fetched in a single pass.
//

import Foundation

nonisolated struct MasterReport: Identifiable, Sendable {
    let id: String
    let name: String
    var info: MasterInfo?
    /// Managed instances, without the API-key holder.
    var instances: [Instance] = []
    /// Why the master could not be reached; `nil` when it answered.
    var failure: String?

    var isReachable: Bool { failure == nil }

    var running: Int { instances.filter { $0.status == .running }.count }
    var stopped: Int { instances.filter { $0.status == .stopped }.count }
    var errors: Int { instances.filter { $0.status == .error }.count }

    var needsAttention: Bool { !isReachable || errors > 0 }

    /// Instances worth a row when space is short: errors first, then running instances by
    /// traffic, then everything else by name.
    func highlightedInstances(limit: Int) -> [Instance] {
        func rank(_ instance: Instance) -> Int {
            switch instance.status {
            case .error: 0
            case .running: 1
            default: 2
            }
        }
        let sorted = instances.sorted { lhs, rhs in
            if rank(lhs) != rank(rhs) { return rank(lhs) < rank(rhs) }
            if lhs.totalTraffic != rhs.totalTraffic { return lhs.totalTraffic > rhs.totalTraffic }
            return lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
        }
        return Array(sorted.prefix(limit))
    }

    // MARK: Loading

    /// Widgets get a few seconds per reload, so requests give up early.
    private static let requestTimeout: TimeInterval = 6

    static func load(_ snapshot: MasterSnapshot) async -> MasterReport {
        var report = MasterReport(id: snapshot.id, name: snapshot.name)
        guard let credentials = snapshot.credentials else {
            report.failure = "Invalid API URL"
            return report
        }
        let client = MasterClient(credentials: credentials, requestTimeout: requestTimeout)
        async let info = client.info()
        async let instances = client.instances()
        do {
            report.info = try await info
            report.instances = ((try? await instances) ?? []).filter { !$0.isAPIKeyHolder }
        } catch {
            report.failure = APIError.wrap(error).shortDescription
        }
        return report
    }

    /// Loads several masters concurrently, keeping their order.
    static func load(_ snapshots: [MasterSnapshot]) async -> [MasterReport] {
        await withTaskGroup(of: (Int, MasterReport).self) { group in
            for (index, snapshot) in snapshots.enumerated() {
                group.addTask { (index, await load(snapshot)) }
            }
            var reports: [(Int, MasterReport)] = []
            for await result in group { reports.append(result) }
            return reports.sorted { $0.0 < $1.0 }.map(\.1)
        }
    }
}
