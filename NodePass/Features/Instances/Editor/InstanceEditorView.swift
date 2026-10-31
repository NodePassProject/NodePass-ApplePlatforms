//
//  InstanceEditorView.swift
//  NodePass
//
//  Create, edit or duplicate an instance. Structured key–value editing with a raw URL mode.
//

import SwiftUI

struct InstanceEditorView: View {
    enum Mode: Identifiable {
        case create(prefill: InstanceURL?)
        case edit(Instance)
        case duplicate(Instance)

        var id: String {
            switch self {
            case .create: "create"
            case .edit(let instance): "edit-\(instance.id)"
            case .duplicate(let instance): "duplicate-\(instance.id)"
            }
        }
    }

    @Environment(\.dismiss) private var dismiss

    var session: MasterSession
    var mode: Mode
    var onComplete: (Instance?) -> Void

    @State private var model: InstanceEditorModel
    @State private var isPickingParameter = false
    @State private var isAddingCustomParameter = false
    @State private var customParameterKey = ""
    @State private var errorMessage: String?
    @State private var revealsCredential = false

    init(session: MasterSession, mode: Mode, onComplete: @escaping (Instance?) -> Void) {
        self.session = session
        self.mode = mode
        self.onComplete = onComplete
        let flavor = session.flavor
        switch mode {
        case .create(let prefill):
            _model = State(initialValue: InstanceEditorModel(flavor: flavor, editing: nil, prefill: prefill))
        case .edit(let instance):
            _model = State(initialValue: InstanceEditorModel(flavor: flavor, editing: instance))
        case .duplicate(let instance):
            _model = State(initialValue: InstanceEditorModel(flavor: flavor, editing: instance, duplicating: true))
        }
    }

    private var title: String {
        switch mode {
        case .create: "New Instance"
        case .edit: "Edit Instance"
        case .duplicate: "Duplicate Instance"
        }
    }

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            Form {
                generalSection
                if model.inputMode == .structured {
                    roleSection
                    endpointSection
                    parametersSection
                } else {
                    textSection
                }
                previewSection
                if let errorMessage {
                    Section { InlineMessage(text: errorMessage, style: .error) }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(title)
            .inlineNavigationTitle()
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .principal) {
                    inputModePicker
                        .frame(maxWidth: 220)
                }
                #endif
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(model.original == nil ? "Create" : "Save", systemImage: "checkmark", role: .confirm) {
                        Task { await save() }
                    }
                    .disabled(!model.canSave)
                }
            }
            .sheet(isPresented: $isPickingParameter) {
                ParameterPickerView(specs: model.availableSpecs) { spec in
                    withAnimation { model.add(spec) }
                } onCustom: { key in
                    withAnimation { model.addCustom(key: key) }
                }
            }
            .alert("Custom Parameter", isPresented: $isAddingCustomParameter) {
                TextField("Key", text: $customParameterKey)
                    .codeInput()
                Button("Add") {
                    withAnimation { model.addCustom(key: customParameterKey) }
                    customParameterKey = ""
                }
                Button("Cancel", role: .cancel) { customParameterKey = "" }
            } message: {
                Text("Unknown keys are passed to the master unchanged.")
            }
        }
        .interactiveDismissDisabled(model.hasChanges && model.original != nil)
        .sheetFrame(width: 640, height: 760)
    }

    private var inputModePicker: some View {
        Picker("Input", selection: Binding(get: { model.inputMode }, set: { model.setInputMode($0) })) {
            ForEach(InstanceEditorModel.InputMode.allCases) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: Sections

    private var generalSection: some View {
        @Bindable var model = model
        return Section {
            #if os(macOS)
            // Sheets on macOS have no title bar to hold the picker.
            inputModePicker
                .labelsHidden()
                .listRowSeparator(.hidden)
            #endif
            TextField("Alias", text: $model.alias, prompt: Text("Optional display name"))
            Toggle(isOn: $model.autoRestart) {
                Label("Auto-restart", systemImage: "arrow.trianglehead.clockwise")
            }
        } footer: {
            if model.urlChanged {
                Text("Saving a changed URL stops and restarts the instance.")
                    .foregroundStyle(.orange)
            }
        }
    }

    private var roleSection: some View {
        Section("Type") {
            RoleSelector(roles: model.flavor.roles, selection: Binding(get: { model.role }, set: { model.setRole($0) }))
                .listRowSeparator(.hidden)
                .padding(.vertical, DS.Spacing.xs)
        }
    }

    @ViewBuilder
    private var endpointSection: some View {
        @Bindable var model = model
        switch model.flavor {
        case .nodePass:
            Section {
                credentialField(title: "Password", prompt: "Optional tunnel key")
                CodeField(title: "Tunnel Host", text: $model.tunnelHost, prompt: model.role == .server ? "0.0.0.0 (all interfaces)" : "server.example.com", input: .url)
                portField("Tunnel Port", text: $model.tunnelPort)
            } header: {
                Text(model.role == .server ? "Tunnel Listener" : "Tunnel Address")
            } footer: {
                Text(model.role == .server
                     ? "Clients connect to this address for the control channel. Leave the host empty to listen on every interface."
                     : "Address of the server's tunnel listener. In single-end mode this is the local listening address instead.")
            }

            Section {
                ForEach($model.targets) { $target in
                    HStack(spacing: 8) {
                        CodeField(title: "Host", text: $target.host, prompt: "127.0.0.1", input: .url)
                            .labelsHidden()
                        Divider()
                        TextField("Port", text: $target.port, prompt: Text("8080"))
                            .labelsHidden()
                            .codeInput(.number)
                            .font(.body.monospaced())
                            .frame(width: 72)
                            .multilineTextAlignment(.trailing)
                        #if os(macOS)
                        RemoveRowButton(title: "Remove Target") { withAnimation { model.removeTarget(target.id) } }
                            .disabled(model.targets.count < 2)
                        #endif
                    }
                }
                .onDelete { offsets in
                    for index in offsets.sorted(by: >) where model.targets.count > 1 {
                        model.targets.remove(at: index)
                    }
                }
                Button("Add Target", systemImage: "plus.circle.fill") {
                    withAnimation { model.addTarget() }
                }
            } header: {
                Text(model.targets.count > 1 ? "Targets" : "Target")
            } footer: {
                if model.targets.count > 1 {
                    Text("Multiple targets are balanced with the `lbs` strategy and require forward mode on servers (mode=2) or single-end mode on clients (mode=1).")
                } else {
                    Text("Destination of the business traffic. Add more targets for load balancing.")
                }
            }

        case .openCtrl:
            Section {
                HStack {
                    credentialField(title: "Shared Key", prompt: "32 lowercase hex characters")
                    Button("Generate", systemImage: "dice") { model.generateSharedKey() }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.borderless)
                }
                CodeField(title: "Host", text: $model.tunnelHost, prompt: model.role == .portal ? "* (all interfaces)" : "portal.example", input: .url)
                Toggle("Declare Carriers in Path", isOn: $model.usesCarrierPaths.animation())
                if !model.usesCarrierPaths {
                    portField("Port", text: $model.tunnelPort)
                }
            } header: {
                Text("Endpoint")
            } footer: {
                Text(model.usesCarrierPaths
                     ? "Each carrier selects a transport: tcp → TLS, udp → QUIC. Use tcp4/udp6 forms to pin an address family."
                     : "A single port serves TLS and QUIC on a Portal; Vector uses TLS and Egress uses QUIC.")
            }

            if model.usesCarrierPaths {
                Section("Carriers") {
                    ForEach($model.carriers) { $carrier in
                        HStack(spacing: 8) {
                            Picker("Carrier", selection: $carrier.kind) {
                                ForEach(Carrier.Kind.allCases, id: \.self) { kind in
                                    Text("\(kind.rawValue) · \(kind.transport)").tag(kind)
                                }
                            }
                            .labelsHidden()
                            Spacer()
                            TextField("Port", text: $carrier.port, prompt: Text("2000"))
                                .labelsHidden()
                                .codeInput(.number)
                                .font(.body.monospaced())
                                .frame(width: 80)
                                .multilineTextAlignment(.trailing)
                            #if os(macOS)
                            RemoveRowButton(title: "Remove Carrier") { withAnimation { model.removeCarrier(carrier.id) } }
                            #endif
                        }
                    }
                    .onDelete { model.carriers.remove(atOffsets: $0) }
                    Button("Add Carrier", systemImage: "plus.circle.fill") {
                        withAnimation { model.addCarrier() }
                    }
                }
            }
        }
    }

    private var parametersSection: some View {
        @Bindable var model = model
        return Section {
            ForEach($model.parameters) { $row in
                ParameterRowView(row: $row, spec: model.spec(for: row.key), isApplicable: model.isApplicable(row.key), roleTitle: model.role.title) {
                    withAnimation { model.remove(row.id) }
                }
            }
            .onDelete { offsets in
                withAnimation { model.parameters.remove(atOffsets: offsets) }
            }
            #if os(macOS)
            addParameterMenu
            #else
            Button("Add Parameter", systemImage: "plus.circle.fill") { isPickingParameter = true }
            #endif
            if !model.inapplicableRows.isEmpty {
                Button("Remove \(model.inapplicableRows.count) Inapplicable", systemImage: "wand.and.sparkles", role: .destructive) {
                    withAnimation { model.removeInapplicable() }
                }
            }
        } header: {
            HStack {
                Text("Parameters")
                Spacer()
                if !model.parameters.isEmpty {
                    Text("\(model.parameters.count)")
                        .textCase(nil)
                }
            }
        } footer: {
            Text("Only parameters listed here are sent. Everything else uses the master's defaults.")
        }
    }

    #if os(macOS)
    /// The catalog as a menu: one submenu per group, searchable by typing while it is open.
    private var addParameterMenu: some View {
        Menu("Add Parameter", systemImage: "plus.circle.fill") {
            ForEach(model.availableSpecs.groupedByCategory, id: \.group) { entry in
                Menu(entry.group.title, systemImage: entry.group.symbolName) {
                    ForEach(entry.specs) { spec in
                        Button {
                            withAnimation { model.add(spec) }
                        } label: {
                            Text(spec.title)
                            Text(spec.key)
                        }
                    }
                }
            }
            Divider()
            Button("Custom Key…") { isAddingCustomParameter = true }
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }
    #endif

    private var textSection: some View {
        @Bindable var model = model
        return Section {
            TextEditor(text: $model.rawText)
                .font(.callout.monospaced())
                .codeInput()
                .frame(minHeight: 120)
                .onChange(of: model.rawText) { model.validateRawText() }
            HStack {
                PasteButton(payloadType: String.self) { strings in
                    if let first = strings.first { model.rawText = first.trimmingCharacters(in: .whitespacesAndNewlines) }
                }
                .labelStyle(.titleAndIcon)
                .buttonBorderShape(.capsule)
                .controlSize(.small)
                Spacer()
                Button("Format", systemImage: "wand.and.stars") {
                    if let parsed = try? InstanceURL(parsing: model.rawText) { model.rawText = parsed.string }
                }
                .disabled(model.rawError != nil)
                .buttonStyle(.borderless)
            }
            .font(.callout)
        } header: {
            Text("Instance URL")
        } footer: {
            Text("`\(model.flavor.roles.map { $0.rawValue + "://" }.joined(separator: " | "))` followed by the endpoint, path and query parameters.")
        }
    }

    private var previewSection: some View {
        Section {
            if model.urlString.isEmpty {
                Text("—")
                    .font(.code(.caption))
                    .foregroundStyle(.tertiary)
            } else {
                InstanceURLText(url: model.urlString, font: .code(.caption))
                    .textSelection(.enabled)
                    .contextMenu {
                        Button("Copy", systemImage: "document.on.document") { Clipboard.copy(model.urlString) }
                    }
            }
            ForEach(model.issues) { issue in
                InlineMessage(text: issue.message, style: issue.severity.messageStyle)
                    .listRowSeparator(.hidden)
            }
        } header: {
            HStack {
                Text("Preview")
                Spacer()
                CopyButton(text: model.urlString)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .textCase(nil)
            }
        }
    }

    // MARK: Pieces

    @ViewBuilder
    private func credentialField(title: String, prompt: String) -> some View {
        @Bindable var model = model
        HStack {
            if revealsCredential {
                CodeField(title: title, text: $model.credential, prompt: prompt)
            } else {
                SecureField(text: $model.credential, prompt: Text(prompt)) {
                    Text(title)
                        .font(.body)
                }
                .font(.body.monospaced())
                .textContentType(.oneTimeCode)
            }
            Button(revealsCredential ? "Hide" : "Reveal", systemImage: revealsCredential ? "eye.slash" : "eye") {
                revealsCredential.toggle()
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
        }
    }

    private func portField(_ title: String, text: Binding<String>) -> some View {
        LabeledContent(title) {
            TextField(title, text: text, prompt: Text("1–65535"))
                .labelsHidden()
                .codeInput(.number)
                .font(.body.monospaced())
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 140)
        }
    }

    // MARK: Save

    private func save() async {
        errorMessage = nil
        do {
            let result = try await model.save(to: session)
            Haptics.success()
            onComplete(model.original == nil ? result : nil)
            dismiss()
        } catch {
            errorMessage = APIError.wrap(error).localizedDescription
            Haptics.warning()
        }
    }
}
