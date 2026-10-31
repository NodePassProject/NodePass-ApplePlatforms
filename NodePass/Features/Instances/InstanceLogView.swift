//
//  InstanceLogView.swift
//  NodePass
//
//  Live log console for one instance: a pushed screen on iOS, its own window on macOS.
//

import SwiftUI
import UniformTypeIdentifiers

struct LogLineRow: View {
    var line: LogLine
    var showsTime = true

    private var tint: Color {
        switch line.level {
        case .error: .red
        case .warn: .orange
        case .debug: .secondary
        case .event: .purple
        case .info: .primary
        case .unknown: .primary
        }
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            if showsTime {
                Text(line.date, format: .dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits).second(.twoDigits))
                    .foregroundStyle(.tertiary)
            }
            Text(line.text)
                .foregroundStyle(tint)
                .textSelection(.enabled)
        }
        .font(.caption.monospaced())
        .listRowInsets(EdgeInsets(top: 2, leading: 12, bottom: 2, trailing: 12))
        .listRowSeparator(.hidden)
    }
}

/// Opens the console of an instance the way the platform expects.
struct ConsoleLink: View {
    var session: MasterSession
    var instanceID: String

    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    #endif

    var body: some View {
        #if os(macOS)
        Button("Open Console", systemImage: "terminal") {
            openWindow(value: ConsoleTarget(masterID: session.id, instanceID: instanceID))
        }
        #else
        NavigationLink {
            InstanceLogView(session: session, instanceID: instanceID)
        } label: {
            Label("Open Console", systemImage: "terminal")
        }
        #endif
    }
}

struct InstanceLogView: View {
    var session: MasterSession
    var instanceID: String

    @State private var searchText = ""
    @State private var levels: Set<LogLine.Level> = []
    @State private var follow = true
    #if os(macOS)
    @State private var selection: Set<LogLine.ID> = []
    @State private var isExporting = false
    #endif

    private var buffer: LogBuffer { session.logBuffer(for: instanceID) }
    private var instanceName: String { session.instance(instanceID)?.displayName ?? "Console" }

    private var lines: [LogLine] {
        var result = buffer.lines
        if !levels.isEmpty { result = result.filter { levels.contains($0.level) } }
        if !searchText.isEmpty { result = result.filter { $0.text.localizedCaseInsensitiveContains(searchText) } }
        return result
    }

    var body: some View {
        ScrollViewReader { proxy in
            lineList
                .overlay {
                    if lines.isEmpty {
                        ContentUnavailableView(
                            buffer.isEmpty ? "No Log Output Yet" : "No Matches",
                            systemImage: "text.alignleft",
                            description: Text(buffer.isEmpty ? "Lines arrive through the live event stream while the instance runs." : "Adjust the search or level filter."))
                    }
                }
                .onChange(of: buffer.count) {
                    guard follow, let last = lines.last else { return }
                    withAnimation(.linear(duration: 0.1)) { proxy.scrollTo(last.id, anchor: .bottom) }
                }
                .onAppear {
                    if let last = lines.last { proxy.scrollTo(last.id, anchor: .bottom) }
                }
        }
        .navigationTitle(instanceName)
        .inlineNavigationTitle()
        #if os(macOS)
        .navigationSubtitle(session.displayName)
        .fileExporter(isPresented: $isExporting, document: PlainTextDocument(text: buffer.exportText), contentType: .plainText, defaultFilename: "\(instanceName).log") { _ in }
        #endif
        .searchable(text: $searchText, placement: .toolbar, prompt: "Filter lines")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Toggle("Follow", systemImage: follow ? "arrow.down.to.line.compact" : "pause", isOn: $follow)
                    .toggleStyle(.button)
                    .help("Keep the newest line in view")
            }
            #if os(iOS)
            ToolbarOverflowMenu {
                consoleMenuItems
            }
            #else
            ToolbarItem(placement: .secondaryAction) {
                consoleMenuItems
            }
            #endif
        }
        .safeAreaBar(edge: .bottom) {
            HStack {
                ConnectionIndicator(state: session.connection)
                Spacer()
                Text("\(lines.count) / \(buffer.count) lines")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
        }
    }

    /// Level filter, export, copy and clear: the overflow menu on iOS, a More menu on the Mac.
    @ViewBuilder
    private var consoleMenuItems: some View {
        Menu("Levels", systemImage: "line.3.horizontal.decrease") {
            ForEach(LogLine.Level.allCases, id: \.self) { level in
                Toggle(level.title, isOn: Binding(
                    get: { levels.contains(level) },
                    set: { if $0 { levels.insert(level) } else { levels.remove(level) } }))
            }
            if !levels.isEmpty {
                Divider()
                Button("Show All") { levels.removeAll() }
            }
        }
        #if os(macOS)
        Button("Save Log…", systemImage: "square.and.arrow.down") { isExporting = true }
            .disabled(buffer.isEmpty)
        #else
        ShareLink(item: buffer.exportText, preview: SharePreview("Instance Log")) {
            Label("Export…", systemImage: "square.and.arrow.up")
        }
        .disabled(buffer.isEmpty)
        #endif
        Button("Copy All", systemImage: "document.on.document") { Clipboard.copy(buffer.exportText) }
            .disabled(buffer.isEmpty)
        Divider()
        Button("Clear", systemImage: "trash", role: .destructive) { session.clearLogs(for: instanceID) }
            .disabled(buffer.isEmpty)
    }

    @ViewBuilder
    private var lineList: some View {
        #if os(macOS)
        // Like Console.app: select any range of lines, then copy them with ⌘C or the context menu.
        List(lines, selection: $selection) { line in
            LogLineRow(line: line)
                .id(line.id)
        }
        .listStyle(.inset)
        .alternatingRowBackgrounds()
        .contextMenu(forSelectionType: LogLine.ID.self) { ids in
            Button("Copy", systemImage: "document.on.document") { Clipboard.copy(text(of: ids)) }
                .disabled(ids.isEmpty)
        }
        .onCopyCommand {
            [NSItemProvider(object: text(of: selection) as NSString)]
        }
        #else
        List {
            ForEach(lines) { line in
                LogLineRow(line: line)
                    .id(line.id)
                    .contextMenu {
                        Button("Copy Line", systemImage: "document.on.document") { Clipboard.copy(line.text) }
                    }
            }
        }
        .listStyle(.plain)
        #endif
    }

    #if os(macOS)
    private func text(of ids: Set<LogLine.ID>) -> String {
        lines.filter { ids.contains($0.id) }.map(\.text).joined(separator: "\n")
    }
    #endif
}
