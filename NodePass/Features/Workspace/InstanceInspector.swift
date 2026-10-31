//
//  InstanceInspector.swift
//  NodePass
//
//  The workspace inspector follows the table selection: the master overview with nothing
//  selected, the instance detail for one instance, and a batch summary for several.
//

#if os(macOS)
import SwiftUI

struct InstanceInspector: View {
    var workspace: InstanceWorkspace

    var body: some View {
        let ids = workspace.selectedIDs
        switch ids.count {
        case 0:
            MasterOverviewView(session: workspace.session, master: workspace.master)
        case 1:
            InstanceDetailView(session: workspace.session, instanceID: ids[0])
                .id(ids[0])
        default:
            SelectionSummaryView(workspace: workspace)
        }
    }
}

private struct SelectionSummaryView: View {
    var workspace: InstanceWorkspace

    var body: some View {
        let instances = workspace.targets()
        Form {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text("\(instances.count) Instances")
                        .font(.title2.weight(.semibold))
                    HStack(spacing: 6) {
                        ForEach(InstanceStatus.knownStatuses, id: \.self) { status in
                            let count = instances.filter { $0.status == status }.count
                            if count > 0 {
                                Pill(text: "\(count) \(status.title)", tint: status.tint)
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            Section {
                InstanceActionBar { workspace.canRun($0) } perform: { workspace.run($0) }
            }

            Section("Traffic") {
                let rates = instances.compactMap { workspace.session.rateTracker(for: $0.id).latest }
                RateLegend(received: rates.reduce(0) { $0 + $1.received }, transmitted: rates.reduce(0) { $0 + $1.transmitted })
                KeyValueRow(key: "Received", value: Format.bytes(instances.reduce(0) { $0 &+ $1.totalReceived }))
                KeyValueRow(key: "Transmitted", value: Format.bytes(instances.reduce(0) { $0 &+ $1.totalTransmitted }))
                KeyValueRow(key: "Connections", value: "\(instances.reduce(0) { $0 + $1.totalConnections })")
            }

            Section("Batch") {
                Button("Enable Auto-restart", systemImage: "arrow.trianglehead.clockwise") { workspace.setAutoRestart(true) }
                    .disabled(workspace.autoRestart() == true)
                Button("Disable Auto-restart", systemImage: "pause.circle") { workspace.setAutoRestart(false) }
                    .disabled(workspace.autoRestart() == false)
                Button("Add Tag…", systemImage: "tag") { workspace.beginTagging() }
                Button("Copy \(instances.count) URLs", systemImage: "document.on.document") { workspace.copyURLs() }
            }

            Section {
                Button("Delete \(instances.count) Instances…", systemImage: "trash", role: .destructive) { workspace.delete() }
            }
        }
        .formStyle(.grouped)
    }
}
#endif
