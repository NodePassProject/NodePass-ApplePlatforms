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
        let rates = instances.compactMap { workspace.session.rateTracker(for: $0.id).latest }
        PanelScreen(tint: .accentColor) {
            HeroHeader(title: "\(instances.count) Instances") {
                ForEach(InstanceStatus.knownStatuses, id: \.self) { status in
                    let count = instances.filter { $0.status == status }.count
                    if count > 0 {
                        Pill(text: "\(count) \(status.title)", tint: status.tint)
                    }
                }
            } meta: {
                Text("Actions below apply to every selected instance.")
            } actions: {
                InstanceActionBar(enabledActions: Set(InstanceAction.allCases.filter { workspace.canRun($0) })) { workspace.run($0) }
            }
        } content: {
            Panel("Traffic", systemImage: "waveform.path.ecg") {
                RateLegend(received: rates.reduce(0) { $0 + $1.received }, transmitted: rates.reduce(0) { $0 + $1.transmitted })
                PanelRows {
                    PropertyRow("Received", value: Format.bytes(instances.reduce(0) { $0 &+ $1.totalReceived }))
                    PropertyRow("Transmitted", value: Format.bytes(instances.reduce(0) { $0 &+ $1.totalTransmitted }))
                    PropertyRow("Connections", value: "\(instances.reduce(0) { $0 + $1.totalConnections })")
                }
            }
            Panel("Batch", systemImage: "checklist") {
                PanelRows {
                    Button("Enable Auto-restart", systemImage: "arrow.trianglehead.clockwise") { workspace.setAutoRestart(true) }
                        .disabled(workspace.autoRestart() == true)
                    Button("Disable Auto-restart", systemImage: "pause.circle") { workspace.setAutoRestart(false) }
                        .disabled(workspace.autoRestart() == false)
                    Button("Add Tag…", systemImage: "tag") { workspace.beginTagging() }
                    Button("Copy \(instances.count) URLs", systemImage: "document.on.document") { workspace.copyURLs() }
                }
                .buttonStyle(.borderless)
                .font(.subheadline)
            }
            Button(role: .destructive) {
                workspace.delete()
            } label: {
                Label("Delete \(instances.count) Instances…", systemImage: "trash")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.bordered)
            .tint(.red)
            .spansAllColumns()
        }
    }
}
#endif
