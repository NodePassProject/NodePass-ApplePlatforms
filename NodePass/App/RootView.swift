//
//  RootView.swift
//  NodePass
//
//  Three-column layout: masters & tools → instances → instance detail / master overview.
//  Collapses to a navigation stack on iPhone.
//

import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(AppSettings.self) private var settings
    @Environment(SessionStore.self) private var sessions
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Server.timestamp) private var masters: [Server]

    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        @Bindable var model = model
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(masters: masters)
        } content: {
            contentColumn
        } detail: {
            detailColumn
        }
        .navigationSplitViewStyle(.balanced)
        .sheet(isPresented: $model.isPresentingNewMaster) {
            MasterEditorView(mode: .create(prefill: nil))
        }
        .sheet(item: $model.masterBeingEdited) { master in
            MasterEditorView(mode: .edit(master))
        }
        .sheet(item: $model.pendingImport) { pending in
            MasterEditorView(mode: .create(prefill: pending))
        }
        .sheet(isPresented: $model.isPresentingSettings) {
            SettingsView()
        }
        .task(id: syncKey) {
            sessions.sync(with: masters, settings: settings)
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            switch phase {
            case .active:
                sessions.activate()
            case .background:
                sessions.deactivate()
            default:
                break
            }
        }
        .onChange(of: settingsKey) {
            sessions.apply(settings)
        }
    }

    /// Changes whenever a master is added, removed or edited.
    private var syncKey: [String] {
        masters.map { "\($0.id)|\($0.name)|\($0.url)|\($0.key)|\($0.isEnabled)|\($0.flavorRawValue ?? "")|\($0.trustsSelfSignedCertificates)" }
    }

    private var settingsKey: String {
        "\(settings.liveEventsEnabled)|\(settings.infoRefreshInterval)|\(settings.instancePollInterval)|\(settings.logBufferSize)"
    }

    @ViewBuilder
    private var contentColumn: some View {
        switch model.sidebarSelection {
        case .master(let id):
            if let session = sessions.session(for: id), let master = masters.first(where: { $0.id == id }) {
                InstanceListView(session: session, master: master)
                    .id(id)
            } else {
                ContentUnavailableView("Master Unavailable", systemImage: "server.rack", description: Text("This master was removed."))
            }
        case .tool(let tool):
            ToolHostView(tool: tool, masters: masters)
        case nil:
            ContentUnavailableView {
                Label("NodePass", systemImage: "point.3.connected.trianglepath.dotted")
            } description: {
                Text(masters.isEmpty ? "Add a master to start managing instances." : "Select a master or a tool.")
            } actions: {
                if masters.isEmpty {
                    Button("Add Master") { model.isPresentingNewMaster = true }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
    }

    @ViewBuilder
    private var detailColumn: some View {
        if case .master(let id) = model.sidebarSelection,
           let session = sessions.session(for: id),
           let master = masters.first(where: { $0.id == id }) {
            if let instanceID = model.selectedInstanceID, session.instance(instanceID) != nil {
                InstanceDetailView(session: session, instanceID: instanceID)
                    .id(instanceID)
            } else {
                MasterOverviewView(session: session, master: master)
            }
        } else if case .tool(let tool) = model.sidebarSelection {
            ContentUnavailableView(tool.title, systemImage: tool.symbolName, description: Text(tool.summary))
        } else {
            ContentUnavailableView("No Selection", systemImage: "sidebar.right", description: Text("Pick an instance to see its details."))
        }
    }
}
