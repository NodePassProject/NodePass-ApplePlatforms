//
//  InstanceDetailView.swift
//  NodePass
//
//  Everything about one instance: a hero header with its state and controls, then panels for
//  live traffic, configuration, metadata and logs. The same view is the macOS inspector.
//
//  The session's instance table, rates and logs change several times a second across all the
//  instances of a master. This view reads them once and hands each panel only the values it
//  shows, as an `Equatable` view, so a panel's body runs again only when its own values moved.
//

import AppIntents
import SwiftUI

struct InstanceDetailView: View {
    @Environment(NavigationModel.self) private var model
    @Environment(AppSettings.self) private var settings

    var session: MasterSession
    var instanceID: String
    /// Edit and More live in the hero instead of the toolbar, for an inspector column that has
    /// no toolbar of its own. Always the case on macOS.
    var showsInlineActions = false

    private var usesInlineActions: Bool {
        #if os(macOS)
        true
        #else
        showsInlineActions
        #endif
    }

    @State private var commander = InstanceCommander()
    @State private var editorMode: InstanceEditorView.Mode?
    @State private var isEditingMeta = false
    @State private var isRenaming = false
    @State private var aliasDraft = ""

    private var instance: Instance? { session.instance(instanceID) }

    var body: some View {
        if let instance {
            content(instance)
        } else {
            ContentUnavailableView("Instance Removed", systemImage: "trash", description: Text("This instance no longer exists on the master."))
        }
    }

    private func content(_ instance: Instance) -> some View {
        let isBusy = session.isBusy(instance.id)
        let tracker = session.rateTracker(for: instance.id)
        let buffer = session.logBuffer(for: instance.id)
        return PanelScreen(tint: instance.status.tint) {
            InstanceHero(
                instance: instance,
                isBusy: isBusy,
                lastErrorLine: instance.status == .error ? buffer.lines.last(where: { $0.level == .error })?.text : nil,
                showsInlineActions: usesInlineActions,
                onAction: { commander.run($0, on: [instance.id], session: session, settings: settings) },
                onEdit: { editorMode = .edit(instance) }
            ) {
                moreMenuItems(instance)
            }
            .equatable()
        } content: {
            TrafficPanel(instance: instance, samples: tracker.samples, isReachable: session.connection.isReachable)
                .equatable()
            ConfigurationPanel(
                url: instance.url, config: instance.config, autoRestart: instance.restart, isBusy: isBusy,
                onEdit: { editorMode = .edit(instance) },
                onSetAutoRestart: { commander.setRestartPolicy($0, on: [instance.id], session: session) })
                .equatable()
            URLPanel(url: instance.url, config: instance.config)
                .equatable()
            MetadataPanel(
                meta: instance.meta,
                onEdit: { isEditingMeta = true },
                onRemoveTag: { commander.removeTag(key: $0, on: [instance.id], session: session) })
                .equatable()
            LogsPanel(lines: Array(buffer.lines.suffix(5)), count: buffer.count, isLive: session.connection == .live,
                      session: session, instanceID: instance.id)
                .equatable()
            Button(role: .destructive) {
                deleteInstance(instance)
            } label: {
                Label("Delete Instance", systemImage: "trash")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.bordered)
            .tint(.red)
            .spansAllColumns()
        }
        .navigationTitle(instance.displayName)
        .inlineNavigationTitle()
        // Tells Siri and Apple Intelligence which instance is on screen.
        .appEntityIdentifier(entityIdentifier(for: instance))
        .userActivity(InstanceEntity.viewingActivityType) { activity in
            activity.title = instance.displayName
            activity.appEntityIdentifier = entityIdentifier(for: instance)
        }
        #if os(iOS)
        .toolbar {
            if !showsInlineActions {
                ToolbarItem(placement: .primaryAction) {
                    Button("Edit", systemImage: "pencil") { editorMode = .edit(instance) }
                }
                ToolbarOverflowMenu {
                    moreMenuItems(instance)
                }
            }
        }
        #endif
        .sheet(item: $editorMode) { mode in
            InstanceEditorView(session: session, mode: mode) { created in
                if let created { model.select(instance: created.id, on: session.id) }
            }
        }
        .sheet(isPresented: $isEditingMeta) {
            InstanceMetaEditorView(session: session, instance: instance)
        }
        .alert("Rename Instance", isPresented: $isRenaming) {
            TextField("Alias", text: $aliasDraft)
            Button("Save") {
                let value = aliasDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !value.isEmpty, value != instance.alias else { return }
                commander.perform { _ = try await session.patch(InstancePatch(alias: value), for: instance.id) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Aliases are stored on the master and visible to every client.")
        }
        .instanceCommanderPresentations(commander)
    }

    @ViewBuilder
    private func moreMenuItems(_ instance: Instance) -> some View {
        Button("Rename…", systemImage: "character.cursor.ibeam") {
            aliasDraft = instance.alias
            isRenaming = true
        }
        Button("Duplicate…", systemImage: "plus.square.on.square") { editorMode = .duplicate(instance) }
        Divider()
        Button("Copy URL", systemImage: "document.on.document") { Clipboard.copy(instance.url) }
        Button("Copy Resolved Config", systemImage: "doc.text") { Clipboard.copy(instance.config) }
            .disabled(instance.config.isEmpty)
        Button("Copy ID", systemImage: "number") { Clipboard.copy(instance.id) }
        ShareLink(item: instance.url) { Label("Share URL", systemImage: "square.and.arrow.up") }
        Divider()
        Button("Delete", systemImage: "trash", role: .destructive) { deleteInstance(instance) }
    }

    private func deleteInstance(_ instance: Instance) {
        commander.delete([instance.id], session: session, settings: settings) {
            model.selectedInstanceIDs.remove(instance.id)
        }
    }

    private func entityIdentifier(for instance: Instance) -> EntityIdentifier {
        EntityIdentifier(for: InstanceEntity.self, identifier: InstanceEntity.ID(masterID: session.id, instanceID: instance.id))
    }
}

// MARK: - Hero

/// State, type, name, identifier and the controls. Compares the fields it shows, not the whole
/// instance, so traffic counters ticking up do not redraw it.
private struct InstanceHero<Menu: View>: View, Equatable {
    var instance: Instance
    var isBusy: Bool
    var lastErrorLine: String?
    var showsInlineActions: Bool
    var onAction: (InstanceAction) -> Void
    var onEdit: () -> Void
    @ViewBuilder var menu: () -> Menu

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.instance.id == rhs.instance.id
            && lhs.instance.displayName == rhs.instance.displayName
            && lhs.instance.status == rhs.instance.status
            && lhs.instance.role == rhs.instance.role
            && lhs.instance.ping == rhs.instance.ping
            && lhs.instance.restart == rhs.instance.restart
            && lhs.instance.url == rhs.instance.url
            && lhs.instance.config == rhs.instance.config
            && lhs.isBusy == rhs.isBusy
            && lhs.lastErrorLine == rhs.lastErrorLine
            && lhs.showsInlineActions == rhs.showsInlineActions
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            HeroHeader(title: instance.displayName) {
                HStack(spacing: 6) {
                    StatusDot(status: instance.status, size: 8, ripples: true)
                    Text(instance.status.title)
                        .font(.subheadline.weight(.semibold))
                        .contentTransition(.interpolate)
                }
                .foregroundStyle(instance.status.tint)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(instance.status.tint.opacity(0.14), in: Capsule())
                .animation(.signal, value: instance.status)
                RolePill(role: instance.role)
                Spacer(minLength: 0)
                if isBusy {
                    ProgressView().controlSize(.small)
                }
                if showsInlineActions {
                    Button("Edit…", action: onEdit)
                        .controlSize(.small)
                    SwiftUI.Menu("More", systemImage: "ellipsis") { menu() }
                        .labelStyle(.iconOnly)
                        .menuIndicator(.hidden)
                        .fixedSize()
                        .controlSize(.small)
                }
            } meta: {
                HStack(spacing: DS.Spacing.m) {
                    MonoText(text: instance.id, size: .footnote)
                    if instance.ping > 0 {
                        Label("\(instance.ping) ms", systemImage: "timer")
                            .font(.footnote.monospacedDigit())
                            .contentTransition(.numericText())
                            .animation(.liveValue, value: instance.ping)
                    }
                    if instance.restart {
                        Label("Auto-restart", systemImage: "arrow.trianglehead.clockwise")
                            .font(.footnote)
                    }
                }
                .labelStyle(.titleAndIcon)
                .lineLimit(1)
            } actions: {
                InstanceActionBar(enabledActions: InstanceAction.applicable(to: instance.status, isBusy: isBusy), perform: onAction)
            }
            if let lastErrorLine {
                InlineMessage(text: lastErrorLine, style: .error)
            }
        }
    }
}

// MARK: - Panels

private struct TrafficPanel: View, Equatable {
    var instance: Instance
    var samples: [RateSample]
    var isReachable: Bool

    var body: some View {
        Panel("Traffic", systemImage: "waveform.path.ecg") {
            if samples.count > 1 {
                VStack(alignment: .leading, spacing: 6) {
                    TrafficSparkline(samples: samples, height: 64)
                    if let latest = samples.last {
                        RateLegend(received: latest.received, transmitted: latest.transmitted)
                    }
                }
            } else {
                Text(isReachable ? "Collecting throughput samples…" : "Throughput appears while the master is connected.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            MetricGrid {
                MetricTile(title: "TCP", value: "\(instance.tcpConnections)", detail: "active", systemImage: "t.square", tint: .indigo)
                MetricTile(title: "UDP", value: "\(instance.udpConnections)", detail: "active", systemImage: "u.square", tint: .teal)
                MetricTile(title: "Pool", value: "\(instance.pool)", detail: "connections", systemImage: "square.stack.3d.up", tint: .purple)
            }
            PanelRows {
                PropertyRow("TCP ↓ / ↑", value: "\(Format.bytes(instance.tcpReceived)) / \(Format.bytes(instance.tcpTransmitted))")
                PropertyRow("UDP ↓ / ↑", value: "\(Format.bytes(instance.udpReceived)) / \(Format.bytes(instance.udpTransmitted))")
                PropertyRow("Total", value: "\(Format.bytes(instance.totalReceived)) / \(Format.bytes(instance.totalTransmitted))")
                if instance.mode != 0 {
                    PropertyRow("Runtime Mode", value: "\(instance.mode)")
                }
            }
        }
    }
}

private struct ConfigurationPanel: View, Equatable {
    var url: String
    var config: String
    var autoRestart: Bool
    var isBusy: Bool
    var onEdit: () -> Void
    var onSetAutoRestart: (Bool) -> Void

    @State private var revealsCredential = false

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.url == rhs.url && lhs.config == rhs.config && lhs.autoRestart == rhs.autoRestart && lhs.isBusy == rhs.isBusy
    }

    var body: some View {
        let parsed = try? InstanceURL(parsing: url)
        Panel("Configuration", systemImage: "slider.horizontal.3") {
            PanelRows {
                Toggle(isOn: Binding(get: { autoRestart }, set: onSetAutoRestart)) {
                    Text("Auto-restart")
                        .font(.subheadline)
                }
                .disabled(isBusy)
                if let parsed {
                    PropertyRow("Type") {
                        RolePill(role: parsed.role)
                    }
                    if let credential = parsed.credential, !credential.isEmpty {
                        PropertyRow(parsed.flavor == .openCtrl ? "Shared Key" : "Password") {
                            HStack(spacing: 6) {
                                Text(revealsCredential ? credential : String(repeating: "•", count: min(credential.count, 12)))
                                    .font(.code(.callout))
                                    .textSelection(.enabled)
                                Button(revealsCredential ? "Hide" : "Reveal", systemImage: revealsCredential ? "eye.slash" : "eye") {
                                    revealsCredential.toggle()
                                }
                                .labelStyle(.iconOnly)
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                    CopyablePropertyRow(key: parsed.flavor == .openCtrl ? "Endpoint" : "Tunnel", value: parsed.tunnel.description)
                    if parsed.flavor == .openCtrl {
                        ForEach(parsed.carriers) { carrier in
                            CopyablePropertyRow(key: "Carrier", value: "\(carrier.description) · \(carrier.kind.transport)")
                        }
                    } else {
                        let targets = parsed.targets
                        ForEach(targets.scopedRows("target")) { row in
                            CopyablePropertyRow(key: targets.count > 1 ? "Target \(row.index + 1)" : "Target", value: row.element.description)
                        }
                    }
                    parameterRows(parsed, resolved: try? InstanceURL(parsing: config))
                }
            }
        } accessory: {
            Button("Edit", action: onEdit)
        }
    }

    @ViewBuilder
    private func parameterRows(_ parsed: InstanceURL, resolved: InstanceURL?) -> some View {
        let explicitKeys = Set(parsed.parameters.map(\.key))
        ForEach(parsed.parameters.scopedRows("parameter")) { row in
            let parameter = row.element
            let spec = ParameterCatalog.spec(key: parameter.key, role: parsed.role)
            PropertyRow(spec?.title ?? parameter.key) {
                VStack(alignment: .trailing, spacing: 1) {
                    Text(spec?.displayValue(parameter.value) ?? parameter.value)
                        .font(.code(.callout))
                        .textSelection(.enabled)
                    if spec?.title != nil {
                        Text("\(parameter.key)=\(parameter.value)")
                            .font(.code(.caption2))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        if let resolved {
            let injected = resolved.parameters.filter { !explicitKeys.contains($0.key) }
            if !injected.isEmpty {
                DisclosureGroup {
                    VStack(spacing: 0) {
                        ForEach(injected.scopedRows("default")) { row in
                            let parameter = row.element
                            let spec = ParameterCatalog.spec(key: parameter.key, role: parsed.role)
                            PropertyRow(spec?.title ?? parameter.key) {
                                Text("\(parameter.key)=\(spec?.displayValue(parameter.value) ?? parameter.value)")
                                    .font(.code(.callout))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 6)
                        }
                    }
                    .padding(.top, 4)
                } label: {
                    Label("\(injected.count) defaults applied by master", systemImage: "wand.and.sparkles")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct URLPanel: View, Equatable {
    var url: String
    var config: String

    @State private var showsResolvedConfig = false
    @State private var revealsCredential = false

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.url == rhs.url && lhs.config == rhs.config
    }

    var body: some View {
        let text = showsResolvedConfig ? config : url
        Panel {
            Picker("Show", selection: $showsResolvedConfig.animation(.signal)) {
                Text("Instance URL").tag(false)
                Text("Resolved Config").tag(true)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            if text.isEmpty {
                Text("—")
                    .font(.code(.callout))
                    .foregroundStyle(.tertiary)
            } else {
                InstanceURLText(url: text, masksCredential: !revealsCredential, font: .code(.footnote))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(DS.Spacing.m)
                    .background(.tileBackground, in: RoundedRectangle(cornerRadius: DS.Radius.tile, style: .continuous))
                    .contextMenu {
                        Button("Copy", systemImage: "document.on.document") { Clipboard.copy(text) }
                        Button(revealsCredential ? "Hide Credential" : "Reveal Credential", systemImage: revealsCredential ? "eye.slash" : "eye") {
                            revealsCredential.toggle()
                        }
                    }
            }
            HStack {
                Text(showsResolvedConfig
                     ? "What the master passes to the process, with its own defaults filled in."
                     : "As stored on the master. Parameters left out fall back to master defaults.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: DS.Spacing.s)
                CopyButton(text: text)
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                    .fixedSize()
            }
        }
    }
}

private struct MetadataPanel: View, Equatable {
    var meta: Instance.Meta
    var onEdit: () -> Void
    var onRemoveTag: (String) -> Void

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.meta == rhs.meta
    }

    var body: some View {
        Panel("Metadata", systemImage: "tag") {
            if !meta.peer.isEmpty {
                PanelRows {
                    CopyablePropertyRow(key: "Peer ID", value: meta.peer.sid)
                    CopyablePropertyRow(key: "Peer Type", value: meta.peer.type)
                    CopyablePropertyRow(key: "Peer Alias", value: meta.peer.alias)
                }
            }
            if meta.tags.isEmpty {
                Text("No tags. Tags are free-form key–value pairs stored on the master; search with key:value or group the list by a tag key.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                FlowLayout(spacing: 6) {
                    ForEach(meta.sortedTags, id: \.key) { tag in
                        TagChip(key: tag.key, value: tag.value)
                            .contextMenu {
                                Button("Copy", systemImage: "document.on.document") { Clipboard.copy("\(tag.key)=\(tag.value)") }
                                Button("Remove Tag", systemImage: "tag.slash", role: .destructive) { onRemoveTag(tag.key) }
                            }
                    }
                }
            }
        } accessory: {
            Button("Edit", action: onEdit)
        }
    }
}

private struct LogsPanel: View, Equatable {
    var lines: [LogLine]
    var count: Int
    var isLive: Bool
    var session: MasterSession
    var instanceID: String

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.lines == rhs.lines && lhs.count == rhs.count && lhs.isLive == rhs.isLive && lhs.instanceID == rhs.instanceID
    }

    var body: some View {
        Panel("Logs", systemImage: "text.alignleft") {
            if lines.isEmpty {
                Text(isLive ? "Waiting for log output…" : "Logs stream only while live events are connected.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(lines) { line in
                        LogLineRow(line: line, showsTime: false)
                            .lineLimit(2)
                    }
                }
                .padding(DS.Spacing.m)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.tileBackground, in: RoundedRectangle(cornerRadius: DS.Radius.tile, style: .continuous))
            }
            ConsoleLink(session: session, instanceID: instanceID)
                .font(.subheadline.weight(.medium))
        } accessory: {
            if count > 0 {
                Text("\(count) lines")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }
}
