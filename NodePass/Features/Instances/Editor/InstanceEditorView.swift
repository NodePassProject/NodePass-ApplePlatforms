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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("Input", selection: Binding(get: { model.inputMode }, set: { model.setInputMode($0) })) {
                        ForEach(InstanceEditorModel.InputMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 220)
                }
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
        }
        .interactiveDismissDisabled(model.hasChanges && model.original != nil)
    }

    // MARK: Sections

    private var generalSection: some View {
        @Bindable var model = model
        return Section {
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
        Section {
            Picker("Type", selection: Binding(get: { model.role }, set: { model.setRole($0) })) {
                ForEach(model.flavor.roles, id: \.self) { role in
                    Label(role.title, systemImage: role.symbolName).tag(role)
                }
            }
            .pickerStyle(.segmented)
            .listRowSeparator(.hidden)
            Text(model.role.summary)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var endpointSection: some View {
        @Bindable var model = model
        switch model.flavor {
        case .nodePass:
            Section {
                credentialField(title: "Password", prompt: "Optional tunnel key")
                CodeField(title: "Tunnel Host", text: $model.tunnelHost, prompt: model.role == .server ? "0.0.0.0 (all interfaces)" : "server.example.com", keyboard: .URL)
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
                        CodeField(title: "Host", text: $target.host, prompt: "127.0.0.1", keyboard: .URL)
                        Divider()
                        TextField("Port", text: $target.port, prompt: Text("8080"))
                            .keyboardType(.numberPad)
                            .font(.body.monospaced())
                            .frame(width: 72)
                            .multilineTextAlignment(.trailing)
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
                    Text("Destination of the business traffic. Swipe to delete, or add more targets for load balancing.")
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
                CodeField(title: "Host", text: $model.tunnelHost, prompt: model.role == .portal ? "* (all interfaces)" : "portal.example", keyboard: .URL)
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
                                .keyboardType(.numberPad)
                                .font(.body.monospaced())
                                .frame(width: 80)
                                .multilineTextAlignment(.trailing)
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
                ParameterRowView(row: $row, spec: model.spec(for: row.key), isApplicable: model.isApplicable(row.key), roleTitle: model.role.title)
            }
            .onDelete { offsets in
                withAnimation { model.parameters.remove(atOffsets: offsets) }
            }
            Button("Add Parameter", systemImage: "plus.circle.fill") { isPickingParameter = true }
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

    private var textSection: some View {
        @Bindable var model = model
        return Section {
            TextEditor(text: $model.rawText)
                .font(.callout.monospaced())
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
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
            MonoText(text: model.urlString.isEmpty ? "—" : model.urlString, size: .caption)
                .foregroundStyle(model.urlString.isEmpty ? .tertiary : .primary)
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
                SecureField(title, text: $model.credential, prompt: Text(prompt))
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
        HStack {
            Text(title)
            Spacer()
            TextField(title, text: text, prompt: Text("1–65535"))
                .keyboardType(.numberPad)
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
