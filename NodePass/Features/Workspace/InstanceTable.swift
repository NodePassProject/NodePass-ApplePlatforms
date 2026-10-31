//
//  InstanceTable.swift
//  NodePass
//
//  The macOS instance table: sortable, customizable columns, multiple selection, sections when
//  grouped, and rows that drag out as their instance URL.
//

#if os(macOS)
import AppIntents
import SwiftUI

struct InstanceTable: View {
    @Environment(NavigationModel.self) private var navigation

    var workspace: InstanceWorkspace
    var groups: [InstanceGroup]
    @Binding var sortOrder: [KeyPathComparator<Instance>]
    @Binding var columnCustomization: TableColumnCustomization<Instance>

    private var session: MasterSession { workspace.session }

    var body: some View {
        @Bindable var navigation = navigation
        Table(of: Instance.self, selection: $navigation.selectedInstanceIDs, sortOrder: $sortOrder, columnCustomization: $columnCustomization) {
            identityColumns
            metricColumns
            detailColumns
        } rows: {
            ForEach(groups) { group in
                if group.title.isEmpty {
                    rows(group.instances)
                } else {
                    Section("\(group.title) · \(group.instances.count)") {
                        rows(group.instances)
                    }
                }
            }
        }
        .alternatingRowBackgrounds()
        // Tells Siri and Apple Intelligence which instances are selected.
        .appEntityIdentifier(forSelectionType: Instance.ID.self) { [masterID = session.id] id in
            EntityIdentifier(for: InstanceEntity.self, identifier: InstanceEntity.ID(masterID: masterID, instanceID: id))
        }
        .contextMenu(forSelectionType: Instance.ID.self) { ids in
            if ids.isEmpty {
                Button("New Instance…", systemImage: "plus") { workspace.createInstance() }
            } else {
                InstanceMenuItems(workspace: workspace, ids: ids)
            }
        } primaryAction: { ids in
            if ids.count == 1, let id = ids.first { workspace.edit(id) }
        }
        .onDeleteCommand { workspace.delete() }
        .copyable(workspace.selectedIDs.isEmpty ? [] : [workspace.targets().map(\.url).joined(separator: "\n")])
        .pasteDestination(for: String.self) { strings in
            workspace.createInstance(fromURLs: strings)
        }
    }

    private func rows(_ instances: [Instance]) -> some TableRowContent<Instance> {
        ForEach(instances) { instance in
            TableRow(instance)
                .draggable(instance.url)
        }
    }

    // MARK: Columns

    @TableColumnBuilder<Instance, KeyPathComparator<Instance>>
    private var identityColumns: some TableColumnContent<Instance, KeyPathComparator<Instance>> {
        TableColumn("Name", value: \.displayName) { instance in
            HStack(spacing: 6) {
                StatusDot(status: instance.status, size: 8)
                Text(instance.displayName)
                    .fontWeight(.medium)
                    .lineLimit(1)
                if session.isBusy(instance.id) {
                    ProgressView().controlSize(.mini)
                }
            }
        }
        .width(min: 120, ideal: 180)
        .customizationID("name")
        .disabledCustomizationBehavior(.visibility)

        TableColumn("Status", value: \.status) { instance in
            StatusPill(status: instance.status)
        }
        .width(min: 60, ideal: 76, max: 110)
        .customizationID("status")

        TableColumn("Type", value: \.role.rawValue) { instance in
            RolePill(role: instance.role)
        }
        .width(min: 64, ideal: 80, max: 120)
        .customizationID("type")

        TableColumn("Endpoint") { instance in
            Text(instance.endpointSummary)
                .font(.callout.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .help(instance.url)
        }
        .width(min: 120, ideal: 240)
        .customizationID("endpoint")
    }

    @TableColumnBuilder<Instance, KeyPathComparator<Instance>>
    private var metricColumns: some TableColumnContent<Instance, KeyPathComparator<Instance>> {
        TableColumn("Connections", value: \.totalConnections) { instance in
            HStack(spacing: 10) {
                Label("\(instance.tcpConnections)", systemImage: "t.square")
                    .help("TCP connections")
                Label("\(instance.udpConnections)", systemImage: "u.square")
                    .help("UDP connections")
            }
            .labelStyle(.titleAndIcon)
            .monospacedDigit()
            .foregroundStyle(instance.totalConnections > 0 ? .primary : .secondary)
            .fixedSize()
        }
        .width(min: 90, ideal: 104)
        .customizationID("connections")

        TableColumn("Pool", value: \.pool) { instance in
            Text(instance.pool > 0 ? "\(instance.pool)" : "—")
                .monospacedDigit()
                .foregroundStyle(instance.pool > 0 ? .primary : .tertiary)
        }
        .width(min: 40, ideal: 50, max: 80)
        .alignment(.trailing)
        .defaultVisibility(.hidden)
        .customizationID("pool")

        TableColumn("Latency", value: \.ping) { instance in
            Text(instance.ping > 0 ? Format.latency(milliseconds: instance.ping) : "—")
                .monospacedDigit()
                .foregroundStyle(instance.ping > 0 ? .primary : .tertiary)
        }
        .width(min: 50, ideal: 64, max: 90)
        .alignment(.trailing)
        .customizationID("latency")

        TableColumn("Throughput") { instance in
            ThroughputCell(sample: session.rateTracker(for: instance.id).latest)
        }
        .width(min: 70, ideal: 90)
        .alignment(.trailing)
        .customizationID("throughput")

        TableColumn("Traffic", value: \.totalTraffic) { instance in
            Text("↓ \(Format.bytes(instance.totalReceived, decimals: 1)) ↑ \(Format.bytes(instance.totalTransmitted, decimals: 1))")
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .width(min: 140, ideal: 180)
        .alignment(.trailing)
        .customizationID("traffic")
    }

    @TableColumnBuilder<Instance, KeyPathComparator<Instance>>
    private var detailColumns: some TableColumnContent<Instance, KeyPathComparator<Instance>> {
        TableColumn("Tags") { instance in
            HStack(spacing: 4) {
                ForEach(instance.meta.sortedTags.prefix(3), id: \.key) { tag in
                    TagChip(key: tag.key, value: tag.value)
                }
                if instance.meta.tags.count > 3 {
                    Text("+\(instance.meta.tags.count - 3)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .width(min: 80, ideal: 160)
        .defaultVisibility(.hidden)
        .customizationID("tags")

        TableColumn("Auto-restart") { instance in
            Toggle("Auto-restart", isOn: Binding(
                get: { instance.restart },
                set: { workspace.setAutoRestart($0, on: [instance.id]) }))
                .labelsHidden()
                .toggleStyle(.checkbox)
                .disabled(session.isBusy(instance.id))
        }
        .width(min: 30, ideal: 84, max: 100)
        .alignment(.center)
        .defaultVisibility(.hidden)
        .customizationID("restart")

        TableColumn("ID", value: \.id) { instance in
            Text(instance.id)
                .font(.callout.monospaced())
                .foregroundStyle(.secondary)
        }
        .width(min: 60, ideal: 90)
        .defaultVisibility(.hidden)
        .customizationID("id")

        TableColumn("URL") { instance in
            Text(instance.url)
                .font(.callout.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .width(min: 160, ideal: 320)
        .defaultVisibility(.hidden)
        .customizationID("url")
    }
}

private struct ThroughputCell: View {
    @Environment(\.backgroundProminence) private var backgroundProminence

    var sample: RateSample?

    var body: some View {
        let rate = sample.map { $0.received + $0.transmitted } ?? 0
        // Selected rows draw their own highlight; keep text legible on it.
        let activeStyle = backgroundProminence == .increased ? AnyShapeStyle(.primary) : AnyShapeStyle(.blue)
        Text(rate > 0 ? Format.bitRate(bytesPerSecond: rate) : "—")
            .monospacedDigit()
            .foregroundStyle(rate > 0 ? activeStyle : AnyShapeStyle(.tertiary))
            .help(sample.map { "↓ \(Format.bitRate(bytesPerSecond: $0.received))  ↑ \(Format.bitRate(bytesPerSecond: $0.transmitted))" } ?? "")
    }
}

// MARK: - Sorting

extension InstanceSortKey {
    /// The table comparator that shows this key and direction in the column headers.
    ///
    /// The list sorts traffic, connections and pool size largest first when "ascending", while
    /// a table header's forward arrow means smallest first; the mapping flips those keys so the
    /// arrow always matches what is on screen.
    func comparator(ascending: Bool) -> KeyPathComparator<Instance> {
        let order: SortOrder = ascending == ascendingIsForward ? .forward : .reverse
        return switch self {
        case .name: KeyPathComparator(\Instance.displayName, order: order)
        case .status: KeyPathComparator(\Instance.status, order: order)
        case .role: KeyPathComparator(\Instance.role.rawValue, order: order)
        case .traffic: KeyPathComparator(\Instance.totalTraffic, order: order)
        case .connections: KeyPathComparator(\Instance.totalConnections, order: order)
        case .pool: KeyPathComparator(\Instance.pool, order: order)
        case .ping: KeyPathComparator(\Instance.ping, order: order)
        case .identifier: KeyPathComparator(\Instance.id, order: order)
        }
    }

    /// The key and direction a clicked column header asks for.
    static func from(_ comparator: KeyPathComparator<Instance>) -> (key: InstanceSortKey, ascending: Bool)? {
        guard let key = allCases.first(where: { $0.comparator(ascending: true).keyPath == comparator.keyPath }) else { return nil }
        return (key, (comparator.order == .forward) == key.ascendingIsForward)
    }

    private var ascendingIsForward: Bool {
        switch self {
        case .traffic, .connections, .pool: false
        default: true
        }
    }
}
#endif
