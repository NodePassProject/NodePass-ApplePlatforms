//
//  InstanceFilter.swift
//  NodePass
//
//  Search, filter, sort and group logic for the instance list.
//

import Foundation

enum InstanceSortKey: String, CaseIterable, Identifiable {
    case name, status, role, traffic, connections, ping, identifier

    var id: String { rawValue }

    var title: String {
        switch self {
        case .name: "Name"
        case .status: "Status"
        case .role: "Type"
        case .traffic: "Traffic"
        case .connections: "Connections"
        case .ping: "Latency"
        case .identifier: "ID"
        }
    }
}

enum InstanceGrouping: String, CaseIterable, Identifiable {
    case none, status, role, tag

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: "None"
        case .status: "Status"
        case .role: "Type"
        case .tag: "Tag"
        }
    }
}

struct InstanceGroup: Identifiable {
    var title: String
    var instances: [Instance]

    var id: String { title }
}

struct InstanceFilter: Hashable {
    var searchText = ""
    /// Empty means every status.
    var statuses: Set<InstanceStatus> = []
    /// Empty means every role.
    var roles: Set<InstanceRole> = []
    /// `true` → only auto-restart, `false` → only manual, `nil` → any.
    var autoRestart: Bool? = nil
    var sortKey: InstanceSortKey = .name
    var ascending = true
    var grouping: InstanceGrouping = .none
    var groupingTagKey = ""

    var isNarrowing: Bool {
        !searchText.isEmpty || !statuses.isEmpty || !roles.isEmpty || autoRestart != nil
    }

    mutating func clearNarrowing() {
        searchText = ""
        statuses = []
        roles = []
        autoRestart = nil
    }

    func apply(to instances: [Instance]) -> [Instance] {
        var result = instances
        if !statuses.isEmpty { result = result.filter { statuses.contains($0.status) } }
        if !roles.isEmpty { result = result.filter { roles.contains($0.role) } }
        if let autoRestart { result = result.filter { $0.restart == autoRestart } }
        if !searchText.isEmpty {
            let needle = searchText.trimmingCharacters(in: .whitespaces)
            if let (key, value) = Self.tagQuery(needle) {
                result = result.filter { instance in
                    guard let tagValue = instance.meta.tags[key] else { return false }
                    return value.isEmpty || tagValue.localizedCaseInsensitiveContains(value)
                }
            } else {
                result = result.filter { $0.searchableText.localizedCaseInsensitiveContains(needle) }
            }
        }
        return result.sorted(by: comparator)
    }

    func grouped(_ instances: [Instance]) -> [InstanceGroup] {
        switch grouping {
        case .none:
            return [InstanceGroup(title: "", instances: instances)]
        case .status:
            return InstanceStatus.knownStatuses.compactMap { status in
                let members = instances.filter { $0.status == status }
                return members.isEmpty ? nil : InstanceGroup(title: status.title, instances: members)
            } + otherGroup(instances.filter { !InstanceStatus.knownStatuses.contains($0.status) }, title: "Other")
        case .role:
            var buckets: [InstanceRole: [Instance]] = [:]
            for instance in instances { buckets[instance.role, default: []].append(instance) }
            let order = InstanceRole.knownRoles
            return buckets.keys.sorted { lhs, rhs in
                let l = order.firstIndex(of: lhs) ?? order.count
                let r = order.firstIndex(of: rhs) ?? order.count
                return l == r ? lhs.rawValue < rhs.rawValue : l < r
            }.map { InstanceGroup(title: $0.title, instances: buckets[$0] ?? []) }
        case .tag:
            let key = groupingTagKey
            var buckets: [String: [Instance]] = [:]
            var untagged: [Instance] = []
            for instance in instances {
                if let value = instance.meta.tags[key], !key.isEmpty {
                    buckets[value, default: []].append(instance)
                } else {
                    untagged.append(instance)
                }
            }
            let tagged = buckets.keys.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
                .map { InstanceGroup(title: "\(key): \($0)", instances: buckets[$0] ?? []) }
            return tagged + otherGroup(untagged, title: key.isEmpty ? "All" : "No “\(key)” tag")
        }
    }

    private func otherGroup(_ members: [Instance], title: String) -> [InstanceGroup] {
        members.isEmpty ? [] : [InstanceGroup(title: title, instances: members)]
    }

    private func comparator(_ lhs: Instance, _ rhs: Instance) -> Bool {
        let result: Bool
        switch sortKey {
        case .name:
            let order = lhs.displayName.localizedStandardCompare(rhs.displayName)
            result = order == .orderedSame ? lhs.id < rhs.id : order == .orderedAscending
        case .status:
            result = lhs.status == rhs.status ? lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending : lhs.status < rhs.status
        case .role:
            result = lhs.role.rawValue == rhs.role.rawValue ? lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending : lhs.role.rawValue < rhs.role.rawValue
        case .traffic:
            result = (lhs.totalReceived &+ lhs.totalTransmitted) > (rhs.totalReceived &+ rhs.totalTransmitted)
        case .connections:
            result = lhs.totalConnections > rhs.totalConnections
        case .ping:
            let l = lhs.ping == 0 ? Int.max : lhs.ping
            let r = rhs.ping == 0 ? Int.max : rhs.ping
            result = l < r
        case .identifier:
            result = lhs.id < rhs.id
        }
        return ascending ? result : !result
    }

    /// Recognizes `key:value` or `#key` search syntax for tags.
    private static func tagQuery(_ text: String) -> (String, String)? {
        if text.hasPrefix("#"), text.count > 1 {
            return (String(text.dropFirst()), "")
        }
        guard let colon = text.firstIndex(of: ":"), colon != text.startIndex else { return nil }
        let key = String(text[..<colon])
        let value = String(text[text.index(after: colon)...])
        guard !key.contains(" "), !key.contains("/") else { return nil }
        return (key, value)
    }
}

extension Collection where Element == Instance {
    /// Distinct tag keys across the collection, sorted.
    var tagKeys: [String] {
        Set(flatMap { $0.meta.tags.keys }).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }
}
