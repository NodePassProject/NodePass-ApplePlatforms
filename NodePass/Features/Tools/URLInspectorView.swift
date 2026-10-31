//
//  URLInspectorView.swift
//  NodePass
//
//  Parses any NodePass / Nowhere URL into its parts and explains every parameter.
//

import SwiftUI
import SwiftData

struct URLInspectorView: View {
    @Environment(NavigationModel.self) private var model
    @Environment(SessionStore.self) private var sessions
    @Query(sort: \Server.timestamp) private var masters: [Server]

    @State private var text = ""
    @State private var editorTarget: (MasterSession, InstanceURL)?
    @State private var isPresentingEditor = false

    private var parsed: Result<InstanceURL, InstanceURLError>? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        do {
            return .success(try InstanceURL(parsing: trimmed))
        } catch {
            return .failure(error)
        }
    }

    var body: some View {
        Form {
            Section {
                TextEditor(text: $text)
                    .font(.callout.monospaced())
                    .codeInput()
                    .frame(minHeight: 90)
                HStack {
                    PasteButton(payloadType: String.self) { strings in
                        if let first = strings.first { text = first.trimmingCharacters(in: .whitespacesAndNewlines) }
                    }
                    .labelStyle(.titleAndIcon)
                    .buttonBorderShape(.capsule)
                    .controlSize(.small)
                    Spacer()
                    Button("Clear", systemImage: "xmark.circle") { text = "" }
                        .disabled(text.isEmpty)
                        .buttonStyle(.borderless)
                }
                .font(.callout)
            } header: {
                Text("URL")
            } footer: {
                Text("Accepts server://, client://, portal://, vector:// and egress:// URLs.")
            }

            switch parsed {
            case .none:
                Section {
                    ForEach(examples, id: \.self) { example in
                        Button {
                            text = example
                        } label: {
                            InstanceURLText(url: example, font: .code(.caption))
                                .foregroundStyle(.primary)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                        }
                    }
                } header: {
                    Text("Examples")
                }
            case .failure(let error):
                Section { InlineMessage(text: error.localizedDescription, style: .error) }
            case .success(let url):
                breakdown(url)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("URL Inspector")
        .inlineNavigationTitle()
        .sheet(isPresented: $isPresentingEditor) {
            if let (session, url) = editorTarget {
                InstanceEditorView(session: session, mode: .create(prefill: url)) { created in
                    if let created { model.select(instance: created.id, on: session.id) }
                }
            }
        }
    }

    private let examples = [
        "server://0.0.0.0:10101/127.0.0.1:8080?tls=1&mode=2&log=info",
        "client://secret@relay.example.com:10101/127.0.0.1:3306?min=32&read=30s",
        "client://127.0.0.1:1080/app1.local:8080,app2.local:8080?mode=1&lbs=1",
        "portal://0123456789abcdef0123456789abcdef@*/tcp:2000/udp:2001?out=egress",
        "vector://0123456789abcdef0123456789abcdef@portal.example:2000?in=127.0.0.1:1080",
    ]

    @ViewBuilder
    private func breakdown(_ url: InstanceURL) -> some View {
        let issues = url.validate()
        if !issues.isEmpty {
            Section("Diagnostics") {
                ForEach(issues) { issue in
                    InlineMessage(text: issue.message, style: issue.severity.messageStyle)
                        .listRowSeparator(.hidden)
                }
            }
        }

        Section("Structure") {
            LabeledContent("Type") {
                RolePill(role: url.role)
            }
            Text(url.role.summary)
                .font(.caption)
                .foregroundStyle(.secondary)
            if let credential = url.credential, !credential.isEmpty {
                KeyValueRow(key: url.flavor == .openCtrl ? "Shared Key" : "Password", value: credential)
            } else if url.flavor == .nodePass, url.tunnel.port != nil {
                KeyValueRow(key: "Tunnel Key", value: "derived from port \(url.tunnel.port ?? 0)", copyable: false)
            }
            KeyValueRow(key: url.flavor == .openCtrl ? "Endpoint" : "Tunnel", value: url.tunnel.description)
            if url.flavor == .openCtrl {
                ForEach(url.carriers) { carrier in
                    KeyValueRow(key: "Carrier", value: "\(carrier.description) · \(carrier.kind.transport) · \(carrier.kind.family)")
                }
            } else {
                let targets = url.targets
                ForEach(Array(targets.enumerated()), id: \.offset) { index, target in
                    KeyValueRow(key: targets.count > 1 ? "Target \(index + 1)" : "Target", value: target.description)
                }
            }
            if let fragment = url.fragment, !fragment.isEmpty {
                KeyValueRow(key: "Fragment", value: fragment)
            }
        }

        Section {
            if url.parameters.isEmpty {
                Text("No parameters; master defaults apply.")
                    .foregroundStyle(.tertiary)
            }
            ForEach(Array(url.parameters.enumerated()), id: \.offset) { _, parameter in
                let spec = ParameterCatalog.spec(key: parameter.key, role: url.role)
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(spec?.title ?? parameter.key)
                        Spacer()
                        Text(spec?.displayValue(parameter.value) ?? parameter.value)
                            .font(.callout.monospaced())
                    }
                    HStack {
                        Text("\(parameter.key)=\(parameter.value)")
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
                        Spacer()
                        if let spec, let problem = spec.validate(parameter.value) {
                            Text(problem).font(.caption2).foregroundStyle(.red)
                        }
                    }
                    if let spec {
                        Text(spec.summary)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        } header: {
            Text("Parameters")
        }

        let unset = ParameterCatalog.specs(for: url.role).filter { !url.hasParameter($0.key) && $0.defaultValue != nil }
        if !unset.isEmpty {
            Section {
                ForEach(unset) { spec in
                    LabeledContent {
                        Text(spec.displayValue(spec.defaultValue ?? ""))
                            .font(.callout.monospaced())
                            .foregroundStyle(.secondary)
                    } label: {
                        Text(spec.title).foregroundStyle(.secondary)
                        Text(spec.key).font(.caption2.monospaced()).foregroundStyle(.tertiary)
                    }
                }
            } header: {
                Text("Defaults in effect")
            } footer: {
                Text("Values the process assumes because the URL does not set them. A master may inject its own defaults for log and TLS.")
            }
        }

        Section {
            InstanceURLText(url: url.string, font: .code(.caption))
                .textSelection(.enabled)
                .contextMenu {
                    Button("Copy", systemImage: "document.on.document") { Clipboard.copy(url.string) }
                }
            CopyButton(text: url.string, label: "Copy Normalized URL")
                .buttonStyle(.borderless)
            let candidates = masters.filter { $0.isEnabled && (sessions.session(for: $0.id)?.flavor ?? $0.resolvedFlavor) == url.flavor }
            if !candidates.isEmpty {
                Menu {
                    ForEach(candidates) { master in
                        Button(master.displayName) {
                            if let session = sessions.session(for: master.id) {
                                editorTarget = (session, url)
                                isPresentingEditor = true
                            }
                        }
                    }
                } label: {
                    Label("Create Instance On…", systemImage: "plus.square.on.square")
                }
            }
        } header: {
            Text("Normalized")
        }
    }
}
