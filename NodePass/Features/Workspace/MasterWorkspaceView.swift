//
//  MasterWorkspaceView.swift
//  NodePass
//
//  The macOS view of one master: filter chips on top, the instance table, live host metrics at
//  the bottom, and an inspector for the selection. iPhone and iPad show the same data in
//  `InstanceListView`.
//

#if os(macOS)
import SwiftUI
import SwiftData

struct MasterWorkspaceView: View {
    @Environment(NavigationModel.self) private var navigation

    @State private var workspace: InstanceWorkspace
    @SceneStorage("NPInstanceTableColumns") private var columnCustomization = TableColumnCustomization<Instance>()
    @AppStorage(NPCore.DefaultsKey.instanceSortKey, store: NPCore.userDefaults) private var sortKeyRaw = InstanceSortKey.name.rawValue
    @AppStorage(NPCore.DefaultsKey.instanceSortAscending, store: NPCore.userDefaults) private var sortAscending = true
    @AppStorage(NPCore.DefaultsKey.instanceGrouping, store: NPCore.userDefaults) private var groupingRaw = InstanceGrouping.none.rawValue
    @AppStorage(NPCore.DefaultsKey.instanceGroupingTag, store: NPCore.userDefaults) private var groupingTagKey = ""

    init(session: MasterSession, master: Server, navigation: NavigationModel, settings: AppSettings) {
        _workspace = State(initialValue: InstanceWorkspace(session: session, master: master, navigation: navigation, settings: settings))
    }

    private var session: MasterSession { workspace.session }
    private var master: Server { workspace.master }

    private var effectiveFilter: InstanceFilter {
        var copy = workspace.filter
        copy.sortKey = InstanceSortKey(rawValue: sortKeyRaw) ?? .name
        copy.ascending = sortAscending
        copy.grouping = InstanceGrouping(rawValue: groupingRaw) ?? .none
        copy.groupingTagKey = groupingTagKey
        return copy
    }

    private var allInstances: [Instance] { session.visibleInstances }
    private var filtered: [Instance] { effectiveFilter.apply(to: allInstances) }

    /// Column headers and the persisted sort settings are two views of the same choice.
    private var sortOrder: Binding<[KeyPathComparator<Instance>]> {
        Binding {
            [(InstanceSortKey(rawValue: sortKeyRaw) ?? .name).comparator(ascending: sortAscending)]
        } set: { newValue in
            guard let first = newValue.first, let choice = InstanceSortKey.from(first) else { return }
            sortKeyRaw = choice.key.rawValue
            sortAscending = choice.ascending
        }
    }

    var body: some View {
        @Bindable var navigation = navigation
        @Bindable var workspace = workspace
        InstanceTable(workspace: workspace, groups: effectiveFilter.grouped(filtered), sortOrder: sortOrder, columnCustomization: $columnCustomization)
            .overlay { overlay }
            .safeAreaBar(edge: .top) { filterBar }
            .safeAreaBar(edge: .bottom) { HostStatusBar(session: session) }
            .navigationTitle(master.displayName)
            .navigationSubtitle(subtitle)
            .searchable(text: $workspace.filter.searchText, placement: .toolbar, prompt: "Search, tag:value or #tag")
            .toolbar(id: "master-workspace") { toolbar }
            .inspector(isPresented: $navigation.isInspectorPresented) {
                InstanceInspector(workspace: workspace)
                    .inspectorColumnWidth(min: 320, ideal: 380, max: 560)
            }
            .sheet(item: $workspace.editorMode) { mode in
                InstanceEditorView(session: session, mode: mode) { created in
                    if let created { workspace.didCreate(created) }
                }
            }
            .alert("Tag Instances", isPresented: Binding(get: { !workspace.tagTargets.isEmpty }, set: { if !$0 { workspace.tagTargets = [] } })) {
                TextField("Key", text: $workspace.tagKey)
                    .codeInput()
                TextField("Value", text: $workspace.tagValue)
                    .codeInput()
                Button("Apply") { workspace.commitTag() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Sets the tag on \(workspace.tagTargets.count == 1 ? "the instance" : "\(workspace.tagTargets.count) instances"); other tags are kept.")
            }
            .instanceCommanderPresentations(workspace.commander)
            .focusedSceneValue(\.instanceWorkspace, workspace)
            .dropDestination(for: String.self) { strings, _ in
                workspace.createInstance(fromURLs: strings)
            }
    }

    // MARK: Pieces

    private var subtitle: String {
        var parts = [session.connection.title]
        if session.hasLoadedInstances {
            let count = allInstances.count
            parts.append(count == 1 ? "1 instance" : "\(count) instances")
        }
        if let version = session.info?.version, !version.isEmpty {
            parts.append("\(session.flavor.title) \(version)")
        }
        return parts.joined(separator: " · ")
    }

    private var filterBar: some View {
        @Bindable var workspace = workspace
        return HStack(spacing: 10) {
            InstanceFilterChips(session: session, filter: $workspace.filter)
            Spacer(minLength: 0)
            if workspace.filter.isNarrowing {
                Text("\(filtered.count) of \(allInstances.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var overlay: some View {
        if allInstances.isEmpty {
            if !session.hasLoadedInstances {
                if case .offline(let reason) = session.connection {
                    ContentUnavailableView {
                        Label("Master Unreachable", systemImage: "wifi.exclamationmark")
                    } description: {
                        Text(session.lastError?.localizedDescription ?? reason)
                    } actions: {
                        Button("Retry") { workspace.refresh() }
                            .buttonStyle(.borderedProminent)
                        Button("Edit Master…") { navigation.masterBeingEdited = master }
                    }
                } else if !master.isEnabled {
                    ContentUnavailableView {
                        Label("Master Disabled", systemImage: "pause.circle")
                    } description: {
                        Text("Enable the master to load its instances.")
                    } actions: {
                        Button("Enable") {
                            master.isEnabled = true
                            try? master.modelContext?.save()
                        }
                    }
                } else {
                    ProgressView("Connecting…")
                }
            } else {
                ContentUnavailableView {
                    Label("No Instances", systemImage: "square.stack.3d.up.slash")
                } description: {
                    Text("Create a \(session.flavor.roles.map { $0.title.lowercased() }.formatted(.list(type: .or))) instance, or drop an instance URL here.")
                } actions: {
                    Button("New Instance…") { workspace.createInstance() }
                        .buttonStyle(.borderedProminent)
                }
            }
        } else if filtered.isEmpty {
            ContentUnavailableView.search(text: workspace.filter.searchText)
        }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbar: some CustomizableToolbarContent {
        ToolbarItem(id: "control", placement: .primaryAction) {
            ControlGroup {
                ForEach([InstanceAction.start, .stop, .restart]) { action in
                    Button(action.title, systemImage: action.symbolName) { workspace.run(action) }
                        .disabled(!workspace.canRun(action))
                        .help(action.title)
                }
            } label: {
                Label("Control", systemImage: "playpause")
            }
        }
        ToolbarItem(id: "new-instance", placement: .primaryAction) {
            Button("New Instance", systemImage: "plus") { workspace.createInstance() }
                .help("New Instance")
        }
        ToolbarItem(id: "view-options", placement: .primaryAction) {
            viewOptionsMenu
        }
        ToolbarItem(id: "refresh", placement: .primaryAction, showsByDefault: false) {
            Button("Refresh", systemImage: "arrow.clockwise") { workspace.refresh() }
                .help("Refresh")
        }
        ToolbarItem(id: "inspector", placement: .primaryAction) {
            Button("Inspector", systemImage: "sidebar.trailing") { navigation.isInspectorPresented.toggle() }
                .help(navigation.isInspectorPresented ? "Hide Inspector" : "Show Inspector")
        }
    }

    private var viewOptionsMenu: some View {
        @Bindable var workspace = workspace
        return Menu("View Options", systemImage: "line.3.horizontal.decrease.circle") {
            Menu("Status") {
                ForEach(InstanceStatus.knownStatuses, id: \.self) { status in
                    Toggle(status.title, isOn: Binding(
                        get: { workspace.filter.statuses.contains(status) },
                        set: { if $0 { workspace.filter.statuses.insert(status) } else { workspace.filter.statuses.remove(status) } }))
                }
            }
            Picker("Auto-restart", selection: $workspace.filter.autoRestart) {
                Text("Any").tag(Bool?.none)
                Text("Enabled").tag(Bool?.some(true))
                Text("Disabled").tag(Bool?.some(false))
            }
            .pickerStyle(.menu)
            Divider()
            Picker("Sort By", selection: $sortKeyRaw) {
                ForEach(InstanceSortKey.allCases) { key in
                    Text(key.title).tag(key.rawValue)
                }
            }
            .pickerStyle(.menu)
            Picker("Group By", selection: $groupingRaw) {
                ForEach(InstanceGrouping.allCases) { grouping in
                    Text(grouping.title).tag(grouping.rawValue)
                }
            }
            .pickerStyle(.menu)
            if groupingRaw == InstanceGrouping.tag.rawValue {
                Picker("Tag Key", selection: $groupingTagKey) {
                    ForEach(allInstances.tagKeys, id: \.self) { key in
                        Text(key).tag(key)
                    }
                }
                .pickerStyle(.menu)
            }
            if workspace.filter.isNarrowing {
                Divider()
                Button("Clear Filters") { workspace.filter.clearNarrowing() }
            }
        }
        .help("Filter, sort and group")
    }
}
#endif
