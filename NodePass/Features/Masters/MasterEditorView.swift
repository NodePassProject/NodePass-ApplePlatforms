//
//  MasterEditorView.swift
//  NodePass
//
//  Add or edit a master, with QR import and a connection test.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct MasterEditorView: View {
    enum Mode {
        case create(prefill: MasterImport?)
        case edit(Server)
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(NavigationModel.self) private var model

    let mode: Mode

    @State private var name = ""
    @State private var url = ""
    @State private var key = ""
    @State private var flavor: MasterFlavorSetting = .automatic
    @State private var trustsSelfSigned = true
    @State private var notes = ""
    @State private var isEnabled = true

    @State private var isScanning = false
    @State private var isImportingImage = false
    @State private var importError: String?
    @State private var isTesting = false
    @State private var testResult: TestResult?
    @State private var isKeyVisible = false

    private enum TestResult {
        case success(MasterInfo, MasterFlavor?)
        case failure(String)
    }

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var normalizedURL: URL? { MasterCredentials.normalizeBaseURL(url) }
    private var canSave: Bool { normalizedURL != nil && !key.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name, prompt: Text("Optional"))
                    CodeField(title: "API URL", text: $url, prompt: "https://host:9090/api/v1", input: .url)
                    HStack {
                        if isKeyVisible {
                            CodeField(title: "API Key", text: $key, prompt: "X-API-Key")
                        } else {
                            SecureField(text: $key, prompt: Text("X-API-Key")) {
                                Text("API Key")
                                    .font(.body)
                            }
                            .font(.body.monospaced())
                            .textContentType(.oneTimeCode)
                        }
                        Button(isKeyVisible ? "Hide key" : "Show key", systemImage: isKeyVisible ? "eye.slash" : "eye") {
                            isKeyVisible.toggle()
                        }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.borderless)
                    }
                } header: {
                    Text("Connection")
                } footer: {
                    Text("Use the full API base URL including the version path: `/api/v1` for NodePass, `/api/v2` for Nowhere OpenCtrl.")
                }

                Section {
                    #if os(iOS)
                    Button {
                        isScanning = true
                    } label: {
                        Label("Scan QR Code", systemImage: "qrcode.viewfinder")
                    }
                    #else
                    Button {
                        isImportingImage = true
                    } label: {
                        Label("Import QR Code Image…", systemImage: "qrcode.viewfinder")
                    }
                    #endif
                    PasteButton(payloadType: String.self) { strings in
                        guard let text = strings.first?.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
                        if let link = URL(string: text), let imported = MasterImport(deepLink: link) {
                            apply(imported)
                        } else if MasterCredentials.normalizeBaseURL(text) != nil {
                            url = text
                        } else {
                            key = text
                        }
                    }
                    .labelStyle(.titleAndIcon)
                    .buttonBorderShape(.capsule)
                    if let importError {
                        InlineMessage(text: importError, style: .warning)
                    }
                } footer: {
                    #if os(macOS)
                    Text("You can also drop an image of a master code onto this window.")
                    #endif
                }

                Section {
                    Picker("API Flavor", selection: $flavor) {
                        ForEach(MasterFlavorSetting.allCases, id: \.self) { setting in
                            Text(setting.title).tag(setting)
                        }
                    }
                    Toggle("Trust Self-signed Certificate", isOn: $trustsSelfSigned)
                    Toggle("Enabled", isOn: $isEnabled)
                } header: {
                    Text("Options")
                } footer: {
                    Text("Masters started with `tls=1` present an auto-generated certificate. Disable trust only when the API uses a publicly valid certificate.")
                }

                Section("Notes") {
                    TextField("Notes", text: $notes, prompt: Text("Location, owner, purpose…"), axis: .vertical)
                        .lineLimit(2...6)
                }

                Section {
                    Button {
                        Task { await testConnection() }
                    } label: {
                        HStack {
                            Label("Test Connection", systemImage: "bolt.horizontal")
                            Spacer()
                            if isTesting { ProgressView() }
                        }
                    }
                    .disabled(!canSave || isTesting)

                    if let testResult {
                        switch testResult {
                        case .success(let info, let detected):
                            VStack(alignment: .leading, spacing: 6) {
                                InlineMessage(text: "Connected to \(info.displayName.isEmpty ? "master" : info.displayName)", style: .success)
                                KeyValueRow(key: "Version", value: info.version)
                                KeyValueRow(key: "Flavor", value: detected?.controllerName ?? "Unknown")
                                KeyValueRow(key: "System", value: "\(info.os) \(info.architecture)")
                                if !info.masterID.isEmpty { KeyValueRow(key: "Master ID", value: info.masterID) }
                            }
                        case .failure(let message):
                            InlineMessage(text: message, style: .error)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(isEditing ? "Edit Master" : "Add Master")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Add", systemImage: "checkmark", role: .confirm) {
                        save()
                    }
                    .disabled(!canSave)
                }
            }
            #if os(iOS)
            .sheet(isPresented: $isScanning) {
                QRCodeScannerView { imported in apply(imported) }
            }
            #else
            .fileImporter(isPresented: $isImportingImage, allowedContentTypes: [.image]) { result in
                if case .success(let url) = result { importCode(fromImageAt: url) }
            }
            .dropDestination(for: URL.self) { urls, _ in
                guard let url = urls.first else { return false }
                importCode(fromImageAt: url)
                return true
            }
            #endif
            .onAppear(perform: load)
        }
        .sheetFrame(width: 520, height: 640)
    }

    private func load() {
        switch mode {
        case .create(let prefill):
            if let prefill { apply(prefill) }
        case .edit(let master):
            name = master.name
            url = master.url
            key = master.key
            flavor = master.flavorSetting
            trustsSelfSigned = master.trustsSelfSignedCertificates
            notes = master.notes ?? ""
            isEnabled = master.isEnabled
        }
    }

    private func apply(_ imported: MasterImport) {
        if name.isEmpty { name = imported.name }
        url = imported.url
        key = imported.key
        testResult = nil
    }

    private func importCode(fromImageAt url: URL) {
        Task {
            do {
                apply(try await QRCodeReader.masterImport(fromImageAt: url))
                importError = nil
            } catch {
                importError = error.localizedDescription
            }
        }
    }

    private func save() {
        guard canSave else { return }
        let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedURL = (normalizedURL?.absoluteString ?? url).trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)

        switch mode {
        case .create:
            let master = Server(name: trimmedName, url: trimmedURL, key: trimmedKey, isEnabled: isEnabled)
            master.flavorSetting = flavor
            master.trustsSelfSignedCertificates = trustsSelfSigned
            master.notes = trimmedNotes.isEmpty ? nil : trimmedNotes
            modelContext.insert(master)
            try? modelContext.save()
            model.select(master: master.id)
        case .edit(let master):
            master.name = trimmedName
            master.url = trimmedURL
            master.key = trimmedKey
            master.isEnabled = isEnabled
            master.flavorSetting = flavor
            master.trustsSelfSignedCertificates = trustsSelfSigned
            master.notes = trimmedNotes.isEmpty ? nil : trimmedNotes
            try? modelContext.save()
        }
        Haptics.success()
        dismiss()
    }

    private func testConnection() async {
        guard let baseURL = normalizedURL else { return }
        isTesting = true
        defer { isTesting = false }
        let client = MasterClient(credentials: MasterCredentials(baseURL: baseURL, apiKey: key.trimmingCharacters(in: .whitespaces), trustsSelfSignedCertificates: trustsSelfSigned))
        do {
            let info = try await client.info()
            var detected = MasterFlavor.infer(fromBaseURL: baseURL)
            if detected == nil {
                let instances = try? await client.instances()
                detected = instances.flatMap { MasterFlavor.infer(fromRoles: $0.map(\.role)) }
            }
            testResult = .success(info, detected)
            Haptics.success()
        } catch {
            testResult = .failure(APIError.wrap(error).localizedDescription)
            Haptics.warning()
        }
    }
}

/// QR code and link for importing a master on another device.
struct MasterShareView: View {
    @Environment(\.dismiss) private var dismiss
    var master: Server

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if let link = master.shareLink {
                    QRCodeImage(content: link.absoluteString, size: 240)
                    Text("Scan with NodePass on another device. The code contains the API key.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    HStack {
                        ShareLink(item: link) {
                            Label("Share Link", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.borderedProminent)
                        CopyButton(text: link.absoluteString, label: "Copy Link")
                            .buttonStyle(.bordered)
                    }
                } else {
                    ContentUnavailableView("Nothing to share", systemImage: "qrcode")
                }
            }
            .padding()
            .navigationTitle(master.displayName)
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", role: .confirm) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .sheetFrame(width: 380, height: 480)
    }
}
