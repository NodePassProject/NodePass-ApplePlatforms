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
    @Environment(NavigationModel.self) private var model
    @Environment(SessionStore.self) private var sessions
    @Environment(\.modelContext) private var modelContext
    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    #endif

    var masters: [Server]

    @AppStorage(NPCore.DefaultsKey.masterSortKey, store: NPCore.userDefaults) private var sortKeyRaw = "date"
    @AppStorage(NPCore.DefaultsKey.masterSortOrder, store: NPCore.userDefaults) private var sortOrderRaw = "ascending"
    @State private var searchText = ""

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
                                Button(role: .destructive) { model.masterPendingDeletion = master } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                Button { model.masterBeingEdited = master } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.orange)
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button { toggleEnabled(master) } label: {
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
        #if os(macOS)
        .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 360)
        .safeAreaInset(edge: .bottom) { bottomBar }
        #else
        .searchable(text: $searchText, placement: .sidebar, prompt: "Search masters")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add Master", systemImage: "plus") { model.isPresentingNewMaster = true }
            }
            ToolbarOverflowMenu {
                sortPickers
                Divider()
                Button("Settings", systemImage: "gear") { model.isPresentingSettings = true }
            }
        }
        #endif
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
    private var sortPickers: some View {
        Picker("Sort By", selection: $sortKeyRaw) {
            ForEach(MasterSortKey.allCases) { key in
                Text(key.title).tag(key.rawValue)
            }
        }
        Picker("Order", selection: $sortOrderRaw) {
            Text("Ascending").tag("ascending")
            Text("Descending").tag("descending")
        }
    }

    #if os(macOS)
    /// Add and sort controls at the foot of the sidebar, where Mac apps keep list management.
    private var bottomBar: some View {
        HStack(spacing: 12) {
            Button("Add Master", systemImage: "plus.circle") { model.isPresentingNewMaster = true }
                .labelStyle(.titleAndIcon)
            Spacer()
            Menu("Sort Masters", systemImage: "arrow.up.arrow.down") { sortPickers }
                .labelStyle(.iconOnly)
                .menuIndicator(.hidden)
                .fixedSize()
                .help("Sort Masters")
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
    #endif

    @ViewBuilder
    private func masterMenu(_ master: Server) -> some View {
        #if os(macOS)
        Button("Open in New Window", systemImage: "macwindow.badge.plus") { openWindow(value: SidebarItem.master(master.id)) }
        Divider()
        #endif
        Button("Edit…", systemImage: "pencil") { model.masterBeingEdited = master }
        Button(master.isEnabled ? "Disable" : "Enable", systemImage: master.isEnabled ? "pause.circle" : "play.circle") {
            toggleEnabled(master)
        }
        Button("Share…", systemImage: "qrcode") { model.masterBeingShared = master }
        Button("Duplicate", systemImage: "plus.square.on.square") { duplicate(master) }
        Divider()
        Button("Delete…", systemImage: "trash", role: .destructive) { model.masterPendingDeletion = master }
    }

    private func toggleEnabled(_ master: Server) {
        master.isEnabled.toggle()
        try? modelContext.save()
    }

    private func duplicate(_ master: Server) {
        let copy = Server(name: master.name + " Copy", url: master.url, key: master.key, isEnabled: false)
        copy.flavorRawValue = master.flavorRawValue
        copy.trustsSelfSignedCertificatesRaw = master.trustsSelfSignedCertificatesRaw
        copy.notes = master.notes
        modelContext.insert(copy)
        try? modelContext.save()
    }
}

/// A master in the sidebar: a tile in its health color carrying the flavor's symbol, the name,
/// what the connection is doing, and how many instances run, with errors called out.
struct MasterRowView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var master: Server
    var session: MasterSession?

    private var health: MasterSession.Health {
        guard master.isEnabled else { return .disabled }
        return session?.health ?? .connecting
    }

    private var flavorSymbol: String {
        (session?.flavor ?? master.resolvedFlavor ?? .nodePass) == .openCtrl ? "circle.hexagongrid" : "server.rack"
    }

    private var tileSize: CGFloat {
        #if os(macOS)
        26
        #else
        32
        #endif
    }

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: tileSize * 0.28, style: .continuous)
                    .fill(health.tint.gradient)
                Image(systemName: flavorSymbol)
                    .font(.system(size: tileSize * 0.46, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: tileSize, height: tileSize)
            .symbolEffect(.pulse, options: .repeating, isActive: health == .connecting && !reduceMotion)
            .animation(.signal, value: health)
            .accessibilityLabel(health.title)
            VStack(alignment: .leading, spacing: 2) {
                Text(master.displayName)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            if let session, master.isEnabled, session.hasLoadedInstances {
                HStack(spacing: 6) {
                    if session.errorCount > 0 {
                        Text("\(session.errorCount)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(InstanceStatus.error.tint, in: Capsule())
                            .accessibilityLabel("\(session.errorCount) in error")
                    }
                    Text("\(session.runningCount)/\(session.counts.total)")
                        .font(.numeral(.caption, weight: .medium))
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                        .accessibilityLabel("\(session.runningCount) of \(session.counts.total) running")
                }
            }
        }
        .padding(.vertical, 2)
    }

    private var summary: String {
        guard master.isEnabled, let session else { return master.host ?? master.url }
        switch session.connection {
        case .offline, .connecting:
            return session.connectionDetail
        case .idle:
            return master.host ?? "Idle"
        case .live, .polling:
            if let info = session.info, !info.version.isEmpty {
                return "\(session.flavor.title) \(info.version) · \(master.host ?? "")"
            }
            return master.host ?? session.connection.title
        }
    }
}
