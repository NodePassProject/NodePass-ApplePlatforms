//
//  RootView.swift
//  NodePass
//
//  The window's split view. Compact widths (iPhone) use three columns (masters & tools →
//  instances → instance detail / master overview) that collapse to a stack. Regular widths (iPad)
//  and macOS use two columns: the sidebar and a master workspace that carries its own inspector,
//  a grid of cards on iPad and a table on the Mac.
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
    @Environment(\.horizontalSizeClass) private var sizeClass
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
                #if DEBUG
                // `xcrun simctl launch <device> com.argsment.NodePass -NPOpenRoute "np://master?id=…"`
                // opens a screen in the simulator, where opening a link asks for confirmation.
                if let link = UserDefaults.standard.string(forKey: "NPOpenRoute"), let url = URL(string: link) {
                    model.handle(deepLink: url)
                }
                #endif
            }
            .onChange(of: model.sidebarSelection) { _, selection in
                windowSelection = selection
            }
            .keepsSessionsInSync()
            .keepsSystemIndexInSync()
            #if os(iOS)
            .keepsWatchInSync()
            #endif
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
        if sizeClass == .regular {
            // iPad: the instances get the width; the detail is an inspector, as on the Mac.
            NavigationSplitView(columnVisibility: $columnVisibility) {
                SidebarView(masters: masters)
            } detail: {
                contentColumn
            }
            .navigationSplitViewStyle(.balanced)
        } else {
            NavigationSplitView(columnVisibility: $columnVisibility) {
                SidebarView(masters: masters)
            } content: {
                contentColumn
            } detail: {
                detailColumn
            }
            .navigationSplitViewStyle(.balanced)
        }
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
            if let instanceID = model.selectedInstanceID, session.instanceIDs.contains(instanceID) {
                InstanceDetailView(session: session, instanceID: instanceID)
                    .id(instanceID)
            } else {
                // Compact widths only reach the detail column by selecting an instance; the
                // master overview opens as a sheet from the list. Keep this column inert instead
                // of evaluating an overview nobody can see on every update of the master.
                ContentUnavailableView("No Selection", systemImage: "sidebar.right", description: Text("Pick an instance to see its details."))
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
