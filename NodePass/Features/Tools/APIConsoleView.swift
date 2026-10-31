//
//  APIConsoleView.swift
//  NodePass
//
//  Raw request builder for the master API.
//

import SwiftUI

struct APIConsoleView: View {
    var masters: [Server]

    private struct Exchange: Identifiable {
        let id = UUID()
        let date: Date
        let masterName: String
        let method: HTTPMethod
        let path: String
        let body: String
        let result: Result<RawResponse, APIError>
    }

    private struct QuickPath: Identifiable {
        let id = UUID()
        let title: String
        let method: HTTPMethod
        let path: String
        let body: String
    }

    @State private var selectedMasterID: String?
    @State private var method: HTTPMethod = .get
    @State private var path = "/instances"
    @State private var requestBody = ""
    @State private var isSending = false
    @State private var history: [Exchange] = []
    @State private var expandedHeaders: Set<UUID> = []

    private var enabledMasters: [Server] { masters.filter(\.isEnabled) }
    private var selectedMaster: Server? { enabledMasters.first { $0.id == selectedMasterID } ?? enabledMasters.first }
    private var methodHasBody: Bool { method == .post || method == .put || method == .patch }

    private let quickPaths: [QuickPath] = [
        QuickPath(title: "List instances", method: .get, path: "/instances", body: ""),
        QuickPath(title: "Master info", method: .get, path: "/info", body: ""),
        QuickPath(title: "Instance by ID", method: .get, path: "/instances/{id}", body: ""),
        QuickPath(title: "Create instance", method: .post, path: "/instances", body: "{\n  \"url\": \"server://0.0.0.0:10101/127.0.0.1:8080?tls=1\",\n  \"alias\": \"example\"\n}"),
        QuickPath(title: "Control instance", method: .patch, path: "/instances/{id}", body: "{\n  \"action\": \"restart\"\n}"),
        QuickPath(title: "Set tags", method: .patch, path: "/instances/{id}", body: "{\n  \"meta\": { \"tags\": { \"env\": \"prod\" } }\n}"),
        QuickPath(title: "TCP ping", method: .get, path: "/tcping?target=1.1.1.1:443", body: ""),
        QuickPath(title: "OpenAPI (NodePass)", method: .get, path: "/openapi.json", body: ""),
    ]

    var body: some View {
        Form {
            Section {
                Picker("Master", selection: Binding(get: { selectedMaster?.id ?? "" }, set: { selectedMasterID = $0 })) {
                    ForEach(enabledMasters) { master in
                        Text(master.displayName).tag(master.id)
                    }
                }
                HStack(spacing: 8) {
                    Picker("Method", selection: $method) {
                        ForEach(HTTPMethod.allCases) { method in
                            Text(method.rawValue).tag(method)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 110)
                    CodeField(title: "Path", text: $path, prompt: "/instances", keyboard: .URL)
                }
                Menu {
                    ForEach(quickPaths) { quick in
                        Button {
                            method = quick.method
                            path = quick.path
                            requestBody = quick.body
                        } label: {
                            Text(quick.title)
                            Text("\(quick.method.rawValue) \(quick.path)")
                        }
                    }
                } label: {
                    Label("Templates", systemImage: "text.badge.plus")
                }
                if methodHasBody {
                    TextEditor(text: $requestBody)
                        .font(.callout.monospaced())
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .frame(minHeight: 110)
                }
            } header: {
                Text("Request")
            } footer: {
                if let master = selectedMaster {
                    Text("Relative to \(master.url). The API key is attached automatically.")
                }
            }

            Section {
                Button {
                    Task { await send() }
                } label: {
                    HStack {
                        Label("Send", systemImage: "paperplane.fill")
                        Spacer()
                        if isSending { ProgressView() }
                    }
                }
                .disabled(selectedMaster == nil || isSending || path.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            ForEach(history) { exchange in
                Section {
                    exchangeView(exchange)
                } header: {
                    HStack {
                        Text("\(exchange.method.rawValue) \(exchange.path)")
                            .font(.caption.monospaced())
                            .textCase(nil)
                            .lineLimit(1)
                        Spacer()
                        Text(exchange.date, style: .time)
                            .textCase(nil)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("API Console")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !history.isEmpty {
                ToolbarItem(placement: .secondaryAction) {
                    Button("Clear History", systemImage: "trash") { history.removeAll() }
                }
            }
        }
        .overlay {
            if enabledMasters.isEmpty {
                ContentUnavailableView("No Enabled Masters", systemImage: "server.rack", description: Text("Add or enable a master to send requests."))
                    .background(.background)
            }
        }
    }

    @ViewBuilder
    private func exchangeView(_ exchange: Exchange) -> some View {
        switch exchange.result {
        case .success(let response):
            HStack(spacing: 8) {
                Pill(text: "\(response.statusCode)", tint: (200...299).contains(response.statusCode) ? .green : .red, prominent: true)
                Text(exchange.masterName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(response.duration * 1000)) ms · \(Format.bytes(UInt64(response.body.count)))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            DisclosureGroup(isExpanded: Binding(
                get: { expandedHeaders.contains(exchange.id) },
                set: { if $0 { expandedHeaders.insert(exchange.id) } else { expandedHeaders.remove(exchange.id) } })) {
                ForEach(response.headers.keys.sorted(), id: \.self) { key in
                    KeyValueRow(key: key, value: response.headers[key] ?? "")
                        .font(.caption)
                }
            } label: {
                Text("\(response.headers.count) headers")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if !response.body.isEmpty {
                ScrollView(.horizontal) {
                    Text(response.prettyBody)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 320)
                CopyButton(text: response.prettyBody, label: "Copy Body")
                    .buttonStyle(.borderless)
            }
        case .failure(let error):
            InlineMessage(text: error.localizedDescription, style: .error)
        }
    }

    private func send() async {
        guard let master = selectedMaster, let credentials = master.credentials else { return }
        isSending = true
        defer { isSending = false }
        let client = MasterClient(credentials: credentials)
        let requestPath = path.trimmingCharacters(in: .whitespaces)
        let requestBody = methodHasBody ? self.requestBody : ""
        let result: Result<RawResponse, APIError>
        do {
            result = .success(try await client.rawRequest(method: method, path: requestPath, body: requestBody.isEmpty ? nil : requestBody))
        } catch {
            result = .failure(APIError.wrap(error))
        }
        history.insert(Exchange(date: .now, masterName: master.displayName, method: method, path: requestPath, body: requestBody, result: result), at: 0)
        if history.count > 30 { history.removeLast(history.count - 30) }
        Haptics.selection()
    }
}
