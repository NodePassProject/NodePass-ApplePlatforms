//
//  SidebarView.swift
//  NodePass
//
//  Masters and tools. Selection drives the content column.
//

import SwiftUI
import SwiftData

private enum MasterSortKey: String, CaseIterable, Identifiable {
    case date, name, status

    var id: String { rawValue }

    var title: String {
        switch self {
        case .date: "Date Added"
        case .name: "Name"
        case .status: "Status"
        }
    }
}

struct SidebarView: View {
    @Environment(AppModel.self) private var model
    @Environment(SessionStore.self) private var sessions
    @Environment(\.modelContext) private var modelContext

    var masters: [Server]

    @AppStorage(NPCore.DefaultsKey.masterSortKey, store: NPCore.userDefaults) private var sortKeyRaw = "date"
    @AppStorage(NPCore.DefaultsKey.masterSortOrder, store: NPCore.userDefaults) private var sortOrderRaw = "ascending"
    @State private var searchText = ""
    @State private var masterToDelete: Server?
    @State private var masterToShare: Server?

    private var sortKey: MasterSortKey { MasterSortKey(rawValue: sortKeyRaw) ?? .date }
    private var ascending: Bool { sortOrderRaw != "descending" }

    private var sortedMasters: [Server] {
        let filtered = searchText.isEmpty ? masters : masters.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText) || $0.url.localizedCaseInsensitiveContains(searchText)
        }
        return filtered.sorted { lhs, rhs in
            let result: Bool
            switch sortKey {
            case .date: result = lhs.timestamp < rhs.timestamp
            case .name: result = lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
            case .status:
                let l = statusRank(lhs), r = statusRank(rhs)
                result = l == r ? lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending : l < r
            }
            return ascending ? result : !result
        }
    }

    private func statusRank(_ master: Server) -> Int {
        guard master.isEnabled else { return 3 }
        switch sessions.session(for: master.id)?.connection {
        case .live, .polling: return 0
        case .connecting, .idle, nil: return 1
        case .offline: return 2
        }
    }

    var body: some View {
        @Bindable var model = model
        List(selection: $model.sidebarSelection) {
            Section {
                if masters.isEmpty {
                    emptyMasters
                } else {
                    ForEach(sortedMasters) { master in
                        MasterRowView(master: master, session: sessions.session(for: master.id))
                            .tag(SidebarItem.master(master.id))
                            .contextMenu { masterMenu(master) }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) { masterToDelete = master } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                Button { model.masterBeingEdited = master } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.orange)
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button {
                                    master.isEnabled.toggle()
                                    try? modelContext.save()
                                } label: {
                                    Label(master.isEnabled ? "Disable" : "Enable", systemImage: master.isEnabled ? "pause.circle" : "play.circle")
                                }
                                .tint(master.isEnabled ? .gray : .green)
                            }
                    }
                }
            } header: {
                Text("Masters")
            }

            Section("Tools") {
                ForEach(Tool.allCases) { tool in
                    Label(tool.title, systemImage: tool.symbolName)
                        .tag(SidebarItem.tool(tool))
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("NodePass")
        .searchable(text: $searchText, placement: .sidebar, prompt: "Search masters")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add Master", systemImage: "plus") { model.isPresentingNewMaster = true }
            }
            ToolbarItem(placement: .secondaryAction) {
                Menu("More", systemImage: "ellipsis.circle") {
                    Picker("Sort By", selection: $sortKeyRaw) {
                        ForEach(MasterSortKey.allCases) { key in
                            Text(key.title).tag(key.rawValue)
                        }
                    }
                    Picker("Order", selection: $sortOrderRaw) {
                        Text("Ascending").tag("ascending")
                        Text("Descending").tag("descending")
                    }
                    Divider()
                    Button("Settings", systemImage: "gear") { model.isPresentingSettings = true }
                }
            }
        }
        .onChange(of: model.sidebarSelection) { oldValue, newValue in
            if oldValue?.masterID != newValue?.masterID {
                model.selectedInstanceID = nil
            }
        }
        .alert("Delete Master?", isPresented: Binding(get: { masterToDelete != nil }, set: { if !$0 { masterToDelete = nil } })) {
            Button("Delete", role: .destructive) {
                if let master = masterToDelete {
                    if model.sidebarSelection == .master(master.id) { model.sidebarSelection = nil }
                    modelContext.delete(master)
                    try? modelContext.save()
                }
                masterToDelete = nil
            }
            Button("Cancel", role: .cancel) { masterToDelete = nil }
        } message: {
            Text("Only the saved connection is removed. Instances on the master are not affected.")
        }
        .sheet(item: $masterToShare) { master in
            MasterShareView(master: master)
        }
    }

    private var emptyMasters: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No masters yet")
                .font(.headline)
            Text("Add a NodePass master or Nowhere OpenCtrl endpoint to manage its instances.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Button("Add Master", systemImage: "plus") { model.isPresentingNewMaster = true }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private func masterMenu(_ master: Server) -> some View {
        Button("Edit", systemImage: "pencil") { model.masterBeingEdited = master }
        Button(master.isEnabled ? "Disable" : "Enable", systemImage: master.isEnabled ? "pause.circle" : "play.circle") {
            master.isEnabled.toggle()
            try? modelContext.save()
        }
        Button("Share…", systemImage: "qrcode") { masterToShare = master }
        Button("Duplicate", systemImage: "plus.square.on.square") {
            let copy = Server(name: master.name + " Copy", url: master.url, key: master.key, isEnabled: false)
            copy.flavorRawValue = master.flavorRawValue
            copy.trustsSelfSignedCertificatesRaw = master.trustsSelfSignedCertificatesRaw
            modelContext.insert(copy)
            try? modelContext.save()
        }
        Divider()
        Button("Delete", systemImage: "trash", role: .destructive) { masterToDelete = master }
    }
}

struct MasterRowView: View {
    var master: Server
    var session: MasterSession?

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: (session?.flavor ?? master.resolvedFlavor ?? .nodePass) == .openCtrl ? "circle.hexagongrid" : "server.rack")
                .font(.title3)
                .foregroundStyle(master.isEnabled ? Color.accentColor : .secondary)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(master.displayName)
                        .font(.body.weight(.medium))
                        .lineLimit(1)
                    if !master.isEnabled {
                        Pill(text: "Off", tint: .secondary)
                    }
                }
                HStack(spacing: 6) {
                    if let session, master.isEnabled {
                        Circle().fill(session.connection.tint).frame(width: 6, height: 6)
                        Text(summary(for: session))
                    } else {
                        Text(master.host ?? master.url)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
            Spacer(minLength: 0)
            if let session, master.isEnabled, session.hasLoadedInstances {
                HStack(spacing: 4) {
                    if session.errorCount > 0 {
                        Text("\(session.errorCount)")
                            .foregroundStyle(.red)
                    }
                    Text("\(session.runningCount)/\(session.visibleInstances.count)")
                        .foregroundStyle(.secondary)
                }
                .font(.caption.monospacedDigit())
            }
        }
        .padding(.vertical, 2)
    }

    private func summary(for session: MasterSession) -> String {
        switch session.connection {
        case .offline(let reason): reason
        case .connecting: "Connecting…"
        case .idle: master.host ?? "Idle"
        case .live, .polling:
            if let info = session.info, !info.version.isEmpty {
                "\(session.flavor.title) \(info.version) · \(master.host ?? "")"
            } else {
                master.host ?? session.connection.title
            }
        }
    }
}
