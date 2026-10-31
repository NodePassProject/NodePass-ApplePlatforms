//
//  InstanceListView.swift
//  NodePass
//
//  Live instance list of one master with filtering, grouping and batch operations (iPhone and
//  iPad). macOS shows the same data in `MasterWorkspaceView`.
//

#if os(iOS)
import SwiftUI

struct InstanceListView: View {
    @Environment(NavigationModel.self) private var model
    @Environment(AppSettings.self) private var settings
    @Environment(\.horizontalSizeClass) private var sizeClass

    var session: MasterSession
    var master: Server

    @AppStorage(NPCore.DefaultsKey.instanceSortKey, store: NPCore.userDefaults) private var sortKeyRaw = InstanceSortKey.name.rawValue
    @AppStorage(NPCore.DefaultsKey.instanceSortAscending, store: NPCore.userDefaults) private var sortAscending = true
    @AppStorage(NPCore.DefaultsKey.instanceGrouping, store: NPCore.userDefaults) private var groupingRaw = InstanceGrouping.none.rawValue
    @AppStorage(NPCore.DefaultsKey.instanceGroupingTag, store: NPCore.userDefaults) private var groupingTagKey = ""

    @State private var filter = InstanceFilter()
    @State private var commander = InstanceCommander()
    @State private var isSelecting = false
    @State private var multiSelection: Set<String> = []
    @State private var editorMode: InstanceEditorView.Mode?
    @State private var isShowingOverview = false
    @State private var isShowingTagPrompt = false
    @State private var batchTagKey = ""
    @State private var batchTagValue = ""

    private var effectiveFilter: InstanceFilter {
        var copy = filter
        copy.sortKey = InstanceSortKey(rawValue: sortKeyRaw) ?? .name
        copy.ascending = sortAscending
        copy.grouping = InstanceGrouping(rawValue: groupingRaw) ?? .none
        copy.groupingTagKey = groupingTagKey
        return copy
    }

    private var allInstances: [Instance] { session.visibleInstances }
    private var filtered: [Instance] { effectiveFilter.apply(to: allInstances) }
    private var groups: [InstanceGroup] { effectiveFilter.grouped(filtered) }

    var body: some View {
        @Bindable var model = model
        Group {
            if isSelecting {
                List(selection: $multiSelection) { listContent }
                    .environment(\.editMode, .constant(.active))
            } else {
                List(selection: $model.selectedInstanceID) { listContent }
            }
        }
        .listStyle(.plain)
        .animation(.default, value: filtered.map(\.id))
        .overlay { overlay }
        .navigationTitle(master.displayName)
        .inlineNavigationTitle()
        .searchable(text: $filter.searchText, placement: .toolbar, prompt: "Search, tag:value or #tag")
        .refreshable {
            await session.refreshInstances()
            await session.refreshInfo()
        }
        .toolbar { toolbarContent }
        .sheet(item: $editorMode) { mode in
            InstanceEditorView(session: session, mode: mode) { created in
                if let created { model.select(instance: created.id, on: session.id) }
            }
        }
        .sheet(isPresented: $isShowingOverview) {
            NavigationStack {
                MasterOverviewView(session: session, master: master, isSheet: true)
            }
        }
        .alert("Tag Selected Instances", isPresented: $isShowingTagPrompt) {
            TextField("Key", text: $batchTagKey)
                .codeInput()
            TextField("Value", text: $batchTagValue)
                .codeInput()
            Button("Apply") {
                commander.applyTag(key: batchTagKey.trimmingCharacters(in: .whitespaces), value: batchTagValue.trimmingCharacters(in: .whitespaces), on: Array(multiSelection), session: session)
                exitSelection()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Sets the tag on every selected instance; other tags are kept.")
        }
        .instanceCommanderPresentations(commander)
        .onChange(of: isSelecting) { _, selecting in
            if !selecting { multiSelection.removeAll() }
        }
    }

    // MARK: List

    @ViewBuilder
    private var listContent: some View {
        Section {
            summaryStrip
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowSeparator(.hidden)
                .selectionDisabled()
        }
        ForEach(groups) { group in
            Section {
                ForEach(group.instances) { instance in
                    InstanceRowView(instance: instance, isBusy: session.isBusy(instance.id), rate: session.rateTracker(for: instance.id).latest)
                        .tag(instance.id)
                        .contextMenu { contextMenu(for: instance) }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if instance.status == .running {
                                Button { commander.run(.stop, on: [instance.id], session: session, settings: settings) } label: {
                                    Label("Stop", systemImage: "stop.fill")
                                }
                                .tint(.orange)
                            } else {
                                Button { commander.run(.start, on: [instance.id], session: session, settings: settings) } label: {
                                    Label("Start", systemImage: "play.fill")
                                }
                                .tint(.green)
                            }
                            Button { commander.run(.restart, on: [instance.id], session: session, settings: settings) } label: {
                                Label("Restart", systemImage: "arrow.clockwise")
                            }
                            .tint(.blue)
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                Clipboard.copy(instance.url)
                                Haptics.selection()
                            } label: {
                                Label("Copy URL", systemImage: "document.on.document")
                            }
                            .tint(.indigo)
                            Button { editorMode = .edit(instance) } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.gray)
                        }
                }
            } header: {
                if !group.title.isEmpty {
                    Text("\(group.title) · \(group.instances.count)")
                }
            }
        }
    }

    private var summaryStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Button {
                    isShowingOverview = true
                } label: {
                    HStack(spacing: 4) {
                        ConnectionIndicator(state: session.connection)
                        if sizeClass == .compact {
                            Image(systemName: "info.circle")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Master info")
                Spacer()
                let rate = session.aggregateRate
                if rate.received + rate.transmitted > 0 {
                    RateLegend(received: rate.received, transmitted: rate.transmitted)
                } else if session.hasLoadedInstances {
                    Text("↓ \(Format.bytes(session.totalReceived, decimals: 1))  ↑ \(Format.bytes(session.totalTransmitted, decimals: 1))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            ScrollView(.horizontal) {
                InstanceFilterChips(session: session, filter: $filter)
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
        }
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
                        Button("Retry") { Task { await session.refreshInstances(); await session.refreshInfo() } }
                            .buttonStyle(.borderedProminent)
                        Button("Edit Master") { model.masterBeingEdited = master }
                    }
                } else if !master.isEnabled {
                    ContentUnavailableView("Master Disabled", systemImage: "pause.circle", description: Text("Enable the master to load its instances."))
                } else {
                    ProgressView("Connecting…")
                }
            } else {
                ContentUnavailableView {
                    Label("No Instances", systemImage: "square.stack.3d.up.slash")
                } description: {
                    Text("Create a \(session.flavor.roles.map { $0.title.lowercased() }.formatted(.list(type: .or))) instance on this master.")
                } actions: {
                    Button("Create Instance", systemImage: "plus") { editorMode = .create(prefill: nil) }
                        .buttonStyle(.borderedProminent)
                }
            }
        } else if filtered.isEmpty {
            ContentUnavailableView.search(text: filter.searchText)
        }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if isSelecting {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { exitSelection() }
            }
            ToolbarItem(placement: .primaryAction) {
                Button(multiSelection.count == filtered.count ? "Deselect All" : "Select All") {
                    if multiSelection.count == filtered.count { multiSelection.removeAll() } else { multiSelection = Set(filtered.map(\.id)) }
                }
            }
            ToolbarItemGroup(placement: .bottomBar) {
                batchBar
            }
        } else {
            ToolbarItemGroup(placement: .primaryAction) {
                Button("Create Instance", systemImage: "plus") { editorMode = .create(prefill: nil) }
                viewMenu
            }
        }
    }

    private var viewMenu: some View {
        Menu("View Options", systemImage: "line.3.horizontal.decrease.circle") {
            Button("Select Instances", systemImage: "checkmark.circle") {
                isSelecting = true
            }
            .disabled(filtered.isEmpty)
            Divider()
            Menu("Status") {
                ForEach(InstanceStatus.knownStatuses, id: \.self) { status in
                    Toggle(status.title, isOn: Binding(
                        get: { filter.statuses.contains(status) },
                        set: { if $0 { filter.statuses.insert(status) } else { filter.statuses.remove(status) } }))
                }
            }
            Menu("Auto-restart") {
                Picker("Auto-restart", selection: $filter.autoRestart) {
                    Text("Any").tag(Bool?.none)
                    Text("Enabled").tag(Bool?.some(true))
                    Text("Disabled").tag(Bool?.some(false))
                }
            }
            Divider()
            Picker("Sort By", selection: $sortKeyRaw) {
                ForEach(InstanceSortKey.allCases) { key in
                    Text(key.title).tag(key.rawValue)
                }
            }
            Toggle("Ascending", isOn: $sortAscending)
            Picker("Group By", selection: $groupingRaw) {
                ForEach(InstanceGrouping.allCases) { grouping in
                    Text(grouping.title).tag(grouping.rawValue)
                }
            }
            if groupingRaw == InstanceGrouping.tag.rawValue {
                Picker("Tag Key", selection: $groupingTagKey) {
                    ForEach(allInstances.tagKeys, id: \.self) { key in
                        Text(key).tag(key)
                    }
                }
            }
            Divider()
            Button("Refresh", systemImage: "arrow.clockwise") {
                Task { await session.refreshInstances() }
            }
            if sizeClass == .compact {
                Button("Master Info", systemImage: "info.circle") { isShowingOverview = true }
            }
        }
    }

    @ViewBuilder
    private var batchBar: some View {
        let ids = Array(multiSelection)
        Menu {
            ForEach(InstanceAction.allCases) { action in
                Button(action.title, systemImage: action.symbolName) {
                    commander.run(action, on: ids, session: session, settings: settings)
                    exitSelection()
                }
            }
        } label: {
            Label("Control", systemImage: "play.circle")
        }
        .disabled(ids.isEmpty)
        Spacer()
        Text(ids.isEmpty ? "Select instances" : "\(ids.count) selected")
            .font(.footnote)
            .foregroundStyle(.secondary)
        Spacer()
        Menu {
            Button("Enable Auto-restart", systemImage: "arrow.trianglehead.clockwise") {
                commander.setRestartPolicy(true, on: ids, session: session)
                exitSelection()
            }
            Button("Disable Auto-restart", systemImage: "pause.circle") {
                commander.setRestartPolicy(false, on: ids, session: session)
                exitSelection()
            }
            Button("Add Tag…", systemImage: "tag") { isShowingTagPrompt = true }
            Button("Copy URLs", systemImage: "document.on.document") {
                Clipboard.copy(ids.compactMap { session.instance($0)?.url }.joined(separator: "\n"))
                exitSelection()
            }
            Divider()
            Button("Delete", systemImage: "trash", role: .destructive) {
                commander.delete(ids, session: session, settings: settings) { exitSelection() }
            }
        } label: {
            Label("More", systemImage: "ellipsis.circle")
        }
        .disabled(ids.isEmpty)
    }

    private func exitSelection() {
        isSelecting = false
        multiSelection.removeAll()
    }

    // MARK: Context menu

    @ViewBuilder
    private func contextMenu(for instance: Instance) -> some View {
        ControlGroup {
            Button("Start", systemImage: "play.fill") { commander.run(.start, on: [instance.id], session: session, settings: settings) }
                .disabled(instance.status == .running)
            Button("Stop", systemImage: "stop.fill") { commander.run(.stop, on: [instance.id], session: session, settings: settings) }
                .disabled(instance.status != .running)
            Button("Restart", systemImage: "arrow.clockwise") { commander.run(.restart, on: [instance.id], session: session, settings: settings) }
        }
        Button("Edit…", systemImage: "pencil") { editorMode = .edit(instance) }
        Button("Duplicate…", systemImage: "plus.square.on.square") { editorMode = .duplicate(instance) }
        Toggle("Auto-restart", systemImage: "arrow.trianglehead.clockwise", isOn: Binding(
            get: { instance.restart },
            set: { commander.setRestartPolicy($0, on: [instance.id], session: session) }))
        Button("Reset Traffic", systemImage: InstanceAction.reset.symbolName) { commander.run(.reset, on: [instance.id], session: session, settings: settings) }
        Divider()
        Button("Copy URL", systemImage: "document.on.document") { Clipboard.copy(instance.url) }
        Button("Copy Resolved Config", systemImage: "doc.text") { Clipboard.copy(instance.config) }
            .disabled(instance.config.isEmpty)
        Button("Copy ID", systemImage: "number") { Clipboard.copy(instance.id) }
        ShareLink(item: instance.url) {
            Label("Share URL", systemImage: "square.and.arrow.up")
        }
        Divider()
        Button("Delete", systemImage: "trash", role: .destructive) {
            commander.delete([instance.id], session: session, settings: settings) {
                model.selectedInstanceIDs.remove(instance.id)
            }
        }
    }
}
#endif
