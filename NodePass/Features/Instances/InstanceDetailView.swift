//
//  InstanceDetailView.swift
//  NodePass
//
//  Everything about one instance: controls, live metrics, configuration, metadata and logs.
//

import AppIntents
import SwiftUI

struct InstanceDetailView: View {
    @Environment(NavigationModel.self) private var model
    @Environment(AppSettings.self) private var settings

    var session: MasterSession
    var instanceID: String

    @State private var commander = InstanceCommander()
    @State private var editorMode: InstanceEditorView.Mode?
    @State private var isEditingMeta = false
    @State private var isRenaming = false
    @State private var aliasDraft = ""
    @State private var showsResolvedConfig = false
    @State private var revealsCredential = false

    private var instance: Instance? { session.instance(instanceID) }

    var body: some View {
        if let instance {
            content(instance)
        } else {
            ContentUnavailableView("Instance Removed", systemImage: "trash", description: Text("This instance no longer exists on the master."))
        }
    }

    private func content(_ instance: Instance) -> some View {
        Form {
            headerSection(instance)
            controlSection(instance)
            trafficSection(instance)
            configurationSection(instance)
            metadataSection(instance)
            logsSection(instance)
            dangerSection(instance)
        }
        .formStyle(.grouped)
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
            ToolbarItem(placement: .primaryAction) {
                Button("Edit", systemImage: "pencil") { editorMode = .edit(instance) }
            }
            ToolbarItem(placement: .secondaryAction) {
                Menu("More", systemImage: "ellipsis.circle") { moreMenuItems(instance) }
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

    // MARK: Header

    private func headerSection(_ instance: Instance) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    StatusPill(status: instance.status, prominent: true)
                    RolePill(role: instance.role)
                    Spacer()
                    if session.isBusy(instance.id) {
                        ProgressView().controlSize(.small)
                    }
                    #if os(macOS)
                    // The inspector has no toolbar of its own.
                    Button("Edit…") { editorMode = .edit(instance) }
                        .controlSize(.small)
                    Menu("More", systemImage: "ellipsis") { moreMenuItems(instance) }
                        .labelStyle(.iconOnly)
                        .menuIndicator(.hidden)
                        .fixedSize()
                        .controlSize(.small)
                    #endif
                }
                Text(instance.displayName)
                    .font(.title2.weight(.semibold))
                    .lineLimit(2)
                HStack(spacing: 10) {
                    MonoText(text: instance.id, size: .caption)
                        .foregroundStyle(.secondary)
                    if instance.ping > 0 {
                        Label("\(instance.ping) ms", systemImage: "timer")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)

            Toggle(isOn: Binding(
                get: { instance.restart },
                set: { commander.setRestartPolicy($0, on: [instance.id], session: session) })) {
                Label("Auto-restart", systemImage: "arrow.trianglehead.clockwise")
            }

            if instance.status == .error, let lastError = session.logBuffer(for: instance.id).lines.last(where: { $0.level == .error }) {
                InlineMessage(text: lastError.text, style: .error)
            }
        }
    }

    private func controlSection(_ instance: Instance) -> some View {
        Section {
            InstanceActionBar { action in
                action.isApplicable(to: instance.status) && !session.isBusy(instance.id)
            } perform: { action in
                commander.run(action, on: [instance.id], session: session, settings: settings)
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
            .listRowBackground(Color.clear)
        }
    }

    // MARK: Traffic

    private func trafficSection(_ instance: Instance) -> some View {
        let tracker = session.rateTracker(for: instance.id)
        return Section("Traffic") {
            if tracker.samples.count > 1 {
                VStack(alignment: .leading, spacing: 6) {
                    TrafficSparkline(samples: tracker.samples, height: 56)
                    if let latest = tracker.latest {
                        RateLegend(received: latest.received, transmitted: latest.transmitted)
                    }
                }
                .padding(.vertical, 4)
            }
            HStack(spacing: 10) {
                MetricTile(title: "TCP", value: "\(instance.tcpConnections)", detail: "active", systemImage: "t.square", tint: .indigo)
                MetricTile(title: "UDP", value: "\(instance.udpConnections)", detail: "active", systemImage: "u.square", tint: .teal)
                MetricTile(title: "Pool", value: "\(instance.pool)", detail: "connections", systemImage: "square.stack.3d.up", tint: .purple)
            }
            .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
            .listRowBackground(Color.clear)
            KeyValueRow(key: "TCP ↓ / ↑", value: "\(Format.bytes(instance.tcpReceived)) / \(Format.bytes(instance.tcpTransmitted))")
            KeyValueRow(key: "UDP ↓ / ↑", value: "\(Format.bytes(instance.udpReceived)) / \(Format.bytes(instance.udpTransmitted))")
            KeyValueRow(key: "Total", value: "\(Format.bytes(instance.totalReceived)) / \(Format.bytes(instance.totalTransmitted))")
            if instance.mode != 0 {
                KeyValueRow(key: "Runtime Mode", value: "\(instance.mode)")
            }
        }
    }

    // MARK: Configuration

    @ViewBuilder
    private func configurationSection(_ instance: Instance) -> some View {
        Section {
            if let parsed = instance.parsedURL {
                KeyValueRow(key: "Scheme", value: parsed.role.rawValue)
                if let credential = parsed.credential, !credential.isEmpty {
                    HStack {
                        Text(parsed.flavor == .openCtrl ? "Shared Key" : "Password")
                        Spacer()
                        Text(revealsCredential ? credential : String(repeating: "•", count: min(credential.count, 12)))
                            .font(.callout.monospaced())
                            .textSelection(.enabled)
                        Button(revealsCredential ? "Hide" : "Reveal", systemImage: revealsCredential ? "eye.slash" : "eye") {
                            revealsCredential.toggle()
                        }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.borderless)
                    }
                }
                KeyValueRow(key: parsed.flavor == .openCtrl ? "Endpoint" : "Tunnel", value: parsed.tunnel.description)
                if parsed.flavor == .openCtrl {
                    ForEach(parsed.carriers) { carrier in
                        KeyValueRow(key: "Carrier", value: "\(carrier.description) · \(carrier.kind.transport)")
                    }
                } else {
                    let targets = parsed.targets
                    ForEach(targets.scopedRows("target")) { row in
                        KeyValueRow(key: targets.count > 1 ? "Target \(row.index + 1)" : "Target", value: row.element.description)
                    }
                }
                parameterRows(parsed, resolved: instance.parsedConfig)
            } else {
                MonoText(text: instance.url, size: .caption)
            }
        } header: {
            HStack {
                Text("Configuration")
                Spacer()
                Button("Edit") { editorMode = .edit(instance) }
                    .font(.caption)
                    .textCase(nil)
            }
        }

        Section {
            Picker("Show", selection: $showsResolvedConfig) {
                Text("Instance URL").tag(false)
                Text("Resolved Config").tag(true)
            }
            .pickerStyle(.segmented)
            .listRowSeparator(.hidden)
            let text = showsResolvedConfig ? instance.config : instance.url
            MonoText(text: text.isEmpty ? "—" : text, size: .caption)
                .foregroundStyle(text.isEmpty ? .tertiary : .primary)
            CopyButton(text: text)
                .buttonStyle(.borderless)
        } footer: {
            Text(showsResolvedConfig
                 ? "The configuration the master passes to the process, with its own defaults filled in."
                 : "The URL as stored on the master. Parameters left out fall back to master defaults.")
        }
    }

    @ViewBuilder
    private func parameterRows(_ parsed: InstanceURL, resolved: InstanceURL?) -> some View {
        let explicitKeys = Set(parsed.parameters.map(\.key))
        ForEach(parsed.parameters.scopedRows("parameter")) { row in
            let parameter = row.element
            let spec = ParameterCatalog.spec(key: parameter.key, role: parsed.role)
            LabeledContent {
                Text(spec?.displayValue(parameter.value) ?? parameter.value)
                    .font(.callout.monospaced())
                    .multilineTextAlignment(.trailing)
                    .textSelection(.enabled)
            } label: {
                Text(spec?.title ?? parameter.key)
                Text(parameter.key)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
            }
        }
        if let resolved {
            let injected = resolved.parameters.filter { !explicitKeys.contains($0.key) }
            if !injected.isEmpty {
                DisclosureGroup {
                    ForEach(injected.scopedRows("default")) { row in
                        let parameter = row.element
                        let spec = ParameterCatalog.spec(key: parameter.key, role: parsed.role)
                        LabeledContent {
                            Text(spec?.displayValue(parameter.value) ?? parameter.value)
                                .font(.callout.monospaced())
                                .foregroundStyle(.secondary)
                        } label: {
                            Text(spec?.title ?? parameter.key)
                                .foregroundStyle(.secondary)
                            Text(parameter.key)
                                .font(.caption2.monospaced())
                                .foregroundStyle(.tertiary)
                        }
                    }
                } label: {
                    Label("\(injected.count) defaults applied by master", systemImage: "wand.and.sparkles")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: Metadata

    private func metadataSection(_ instance: Instance) -> some View {
        Section {
            if !instance.meta.peer.isEmpty {
                KeyValueRow(key: "Peer ID", value: instance.meta.peer.sid)
                KeyValueRow(key: "Peer Type", value: instance.meta.peer.type)
                KeyValueRow(key: "Peer Alias", value: instance.meta.peer.alias)
            }
            if instance.meta.tags.isEmpty {
                Text("No tags")
                    .foregroundStyle(.tertiary)
            } else {
                FlowLayout(spacing: 6) {
                    ForEach(instance.meta.sortedTags, id: \.key) { tag in
                        TagChip(key: tag.key, value: tag.value)
                            .contextMenu {
                                Button("Copy", systemImage: "document.on.document") { Clipboard.copy("\(tag.key)=\(tag.value)") }
                                Button("Remove Tag", systemImage: "tag.slash", role: .destructive) {
                                    commander.removeTag(key: tag.key, on: [instance.id], session: session)
                                }
                            }
                    }
                }
                .padding(.vertical, 2)
            }
        } header: {
            HStack {
                Text("Metadata")
                Spacer()
                Button("Edit") { isEditingMeta = true }
                    .font(.caption)
                    .textCase(nil)
            }
        } footer: {
            Text("Tags are free-form key–value pairs stored on the master. Search with `key:value` or group the list by a tag key.")
        }
    }

    // MARK: Logs

    private func logsSection(_ instance: Instance) -> some View {
        let buffer = session.logBuffer(for: instance.id)
        return Section {
            if buffer.isEmpty {
                Text(session.connection == .live ? "Waiting for log output…" : "Logs stream only while live events are connected.")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
            } else {
                ForEach(buffer.lines.suffix(4)) { line in
                    LogLineRow(line: line, showsTime: false)
                }
            }
            ConsoleLink(session: session, instanceID: instance.id)
        } header: {
            HStack {
                Text("Logs")
                Spacer()
                if !buffer.isEmpty {
                    Text("\(buffer.count) lines")
                        .font(.caption)
                        .textCase(nil)
                }
            }
        }
    }

    private func dangerSection(_ instance: Instance) -> some View {
        Section {
            Button("Delete Instance", systemImage: "trash", role: .destructive) { deleteInstance(instance) }
        }
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
