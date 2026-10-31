//
//  InstanceLogView.swift
//  NodePass
//
//  Live log console for one instance.
//

import SwiftUI

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

struct InstanceLogView: View {
    var session: MasterSession
    var instanceID: String

    @State private var searchText = ""
    @State private var levels: Set<LogLine.Level> = []
    @State private var follow = true

    private var buffer: LogBuffer { session.logBuffer(for: instanceID) }

    private var lines: [LogLine] {
        var result = buffer.lines
        if !levels.isEmpty { result = result.filter { levels.contains($0.level) } }
        if !searchText.isEmpty { result = result.filter { $0.text.localizedCaseInsensitiveContains(searchText) } }
        return result
    }

    var body: some View {
        ScrollViewReader { proxy in
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
        .navigationTitle(session.instance(instanceID)?.displayName ?? "Console")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, placement: .toolbar, prompt: "Filter lines")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Toggle("Follow", systemImage: follow ? "arrow.down.to.line.compact" : "pause", isOn: $follow)
                    .toggleStyle(.button)
            }
            ToolbarItem(placement: .secondaryAction) {
                Menu("More", systemImage: "ellipsis.circle") {
                    Menu("Levels") {
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
                    ShareLink(item: buffer.exportText, preview: SharePreview("Instance Log")) {
                        Label("Export…", systemImage: "square.and.arrow.up")
                    }
                    .disabled(buffer.isEmpty)
                    Button("Copy All", systemImage: "document.on.document") { Clipboard.copy(buffer.exportText) }
                        .disabled(buffer.isEmpty)
                    Divider()
                    Button("Clear", systemImage: "trash", role: .destructive) { session.clearLogs(for: instanceID) }
                        .disabled(buffer.isEmpty)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            HStack {
                ConnectionIndicator(state: session.connection)
                Spacer()
                Text("\(lines.count) / \(buffer.count) lines")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
            .background(.bar)
        }
    }
}
