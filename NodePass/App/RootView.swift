//
//  RootView.swift
//  NodePass
//
//  The window's split view. iPhone and iPad use three columns (masters & tools → instances →
//  instance detail / master overview) that collapse to a stack on iPhone. macOS uses two columns:
//  the sidebar and a master workspace that carries its own inspector.
//
//  Master-level presentations (add, edit, share, delete, key rotation) live here so the sidebar,
//  the master overview and the menu bar commands all trigger the same flows.
//

import AppIntents
import SwiftUI
import SwiftData

struct RootView: View {
    /// The window's restorable selection, owned by the window scene.
    @Binding var windowSelection: SidebarItem?

    @Environment(AppSettings.self) private var settings
    @Environment(SessionStore.self) private var sessions
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Server.timestamp) private var masters: [Server]

    @State private var model = NavigationModel()
    @State private var keyRotationError: String?
    #if os(iOS)
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    #endif

    var body: some View {
        @Bindable var model = model
        splitView
            .sheet(isPresented: $model.isPresentingNewMaster) {
                MasterEditorView(mode: .create(prefill: nil))
            }
            .sheet(item: $model.masterBeingEdited) { master in
                MasterEditorView(mode: .edit(master))
            }
            .sheet(item: $model.pendingImport) { pending in
                MasterEditorView(mode: .create(prefill: pending))
            }
            .sheet(item: $model.masterBeingShared) { master in
                MasterShareView(master: master)
            }
            #if os(iOS)
            .sheet(isPresented: $model.isPresentingSettings) {
                SettingsView()
            }
            #endif
            .alert("Delete Master?", isPresented: Binding(isPresenting: $model.masterPendingDeletion), presenting: model.masterPendingDeletion) { master in
                Button("Delete", role: .destructive) { delete(master) }
                Button("Cancel", role: .cancel) {}
            } message: { _ in
                Text("Only the saved connection is removed. Instances on the master are not affected.")
            }
            .alert("Rotate API Key?", isPresented: Binding(isPresenting: $model.masterPendingKeyRotation), presenting: model.masterPendingKeyRotation) { master in
                Button("Rotate", role: .destructive) { Task { await rotateKey(of: master) } }
                Button("Cancel", role: .cancel) {}
            } message: { _ in
                Text("The master generates a new key immediately. Every other client using the current key loses access. This app updates its saved key automatically.")
            }
            .alert("Rotation Failed", isPresented: Binding(isPresenting: $keyRotationError)) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(keyRotationError ?? "")
            }
            .onOpenURL { url in
                model.handle(deepLink: url)
            }
            #if os(iOS)
            // Foreground intents land in the scene the system targets. macOS has no such hook;
            // there the intents open the matching deep link instead (`IntentNavigator`).
            .onAppIntentExecution(OpenMasterIntent.self) { intent in
                model.select(master: intent.target.id)
            }
            .onAppIntentExecution(OpenInstanceIntent.self) { intent in
                model.select(instance: intent.target.id.instanceID, on: intent.target.id.masterID)
            }
            .onAppIntentExecution(OpenToolIntent.self) { intent in
                model.sidebarSelection = .tool(intent.tool)
            }
            #endif
            #if os(macOS)
            // Route deep links and widget taps to an open window instead of opening a new one.
            .handlesExternalEvents(preferring: ["*"], allowing: ["*"])
            .frame(minWidth: 860, minHeight: 520)
            .focusedSceneValue(\.navigationModel, model)
            #endif
            .onAppear {
                if model.sidebarSelection == nil { model.sidebarSelection = windowSelection }
            }
            .onChange(of: model.sidebarSelection) { _, selection in
                windowSelection = selection
            }
            .keepsSessionsInSync()
            .keepsSystemIndexInSync()
            .environment(model)
    }

    // MARK: Layout

    @ViewBuilder
    private var splitView: some View {
        #if os(macOS)
        NavigationSplitView {
            SidebarView(masters: masters)
        } detail: {
            workspace
        }
        #else
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(masters: masters)
        } content: {
            contentColumn
        } detail: {
            detailColumn
        }
        .navigationSplitViewStyle(.balanced)
        #endif
    }

    #if os(macOS)
    @ViewBuilder
    private var workspace: some View {
        switch model.sidebarSelection {
        case .master(let id):
            masterContent(id) { session, master in
                MasterWorkspaceView(session: session, master: master, navigation: model, settings: settings)
                    .id(id)
            }
        case .tool(let tool):
            ToolHostView(tool: tool, masters: masters)
        case nil:
            welcome
        }
    }
    #else
    @ViewBuilder
    private var contentColumn: some View {
        switch model.sidebarSelection {
        case .master(let id):
            masterContent(id) { session, master in
                InstanceListView(session: session, master: master)
                    .id(id)
            }
        case .tool(let tool):
            ToolHostView(tool: tool, masters: masters)
        case nil:
            welcome
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
    #endif

    /// Resolves a master and its live session. The session appears a moment after a master is
    /// added, so a missing session alone shows progress rather than an error.
    @ViewBuilder
    private func masterContent(_ id: String, @ViewBuilder content: (MasterSession, Server) -> some View) -> some View {
        if let master = masters.first(where: { $0.id == id }) {
            if let session = sessions.session(for: id) {
                content(session, master)
            } else {
                ProgressView()
            }
        } else {
            ContentUnavailableView("Master Unavailable", systemImage: "server.rack", description: Text("This master was removed."))
        }
    }

    private var welcome: some View {
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

    // MARK: Master actions

    private func delete(_ master: Server) {
        if model.selectedMasterID == master.id { model.sidebarSelection = nil }
        modelContext.delete(master)
        try? modelContext.save()
    }

    private func rotateKey(of master: Server) async {
        guard let session = sessions.session(for: master.id) else { return }
        do {
            let newKey = try await session.regenerateAPIKey()
            guard !newKey.isEmpty else { throw APIError.invalidResponse }
            master.key = newKey
            try? modelContext.save()
            Haptics.success()
        } catch {
            keyRotationError = APIError.wrap(error).localizedDescription
            Haptics.warning()
        }
    }
}
