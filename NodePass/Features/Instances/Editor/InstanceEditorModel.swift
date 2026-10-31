//
//  InstanceEditorModel.swift
//  NodePass
//
//  Editing state for an instance URL. The structured fields and the raw text are two views of
//  the same `InstanceURL`; switching modes re-derives one from the other.
//

import Foundation
import Observation

@Observable
@MainActor
final class InstanceEditorModel {
    enum InputMode: String, CaseIterable, Identifiable {
        case structured = "Structured"
        case text = "URL"
        var id: String { rawValue }
    }

    struct ParameterRow: Identifiable, Hashable {
        let id: UUID
        var key: String
        var value: String

        init(key: String, value: String) {
            self.id = UUID()
            self.key = key
            self.value = value
        }
    }

    struct TargetRow: Identifiable, Hashable {
        let id = UUID()
        var host: String
        var port: String
    }

    struct CarrierRow: Identifiable, Hashable {
        let id = UUID()
        var kind: Carrier.Kind
        var port: String
    }

    let flavor: MasterFlavor
    /// Instance being edited; nil when creating.
    let original: Instance?

    var alias: String
    var autoRestart: Bool
    var inputMode: InputMode = .structured

    var role: InstanceRole
    var credential = ""
    var tunnelHost = ""
    var tunnelPort = ""
    var targets: [TargetRow] = []
    var carriers: [CarrierRow] = []
    var usesCarrierPaths = false
    var parameters: [ParameterRow] = []
    var fragment: String?

    var rawText = ""
    var rawError: String?

    private let originalAlias: String
    private let originalRestart: Bool
    private let originalURL: String

    // MARK: Init

    init(flavor: MasterFlavor, editing instance: Instance?, duplicating: Bool = false, prefill: InstanceURL? = nil) {
        self.flavor = flavor
        self.original = duplicating ? nil : instance
        self.role = flavor.defaultRole
        self.alias = ""
        self.autoRestart = true
        self.originalAlias = instance?.alias ?? ""
        self.originalRestart = instance?.restart ?? true
        self.originalURL = instance?.url ?? ""

        if let instance {
            alias = duplicating ? (instance.alias.isEmpty ? "" : instance.alias + " copy") : instance.alias
            autoRestart = instance.restart
            if let parsed = instance.parsedURL {
                load(parsed)
            } else {
                inputMode = .text
                rawText = instance.url
                rawError = "The stored URL could not be parsed. Edit it as text."
            }
        } else if let prefill {
            load(prefill)
        } else {
            applyRoleDefaults()
        }
    }

    // MARK: Loading

    func load(_ url: InstanceURL) {
        role = url.role.flavor == flavor ? url.role : flavor.defaultRole
        credential = url.credential ?? ""
        tunnelHost = url.tunnel.host
        tunnelPort = url.tunnel.port.map(String.init) ?? ""
        fragment = url.fragment
        parameters = url.parameters.map { ParameterRow(key: $0.key, value: $0.value) }
        switch flavor {
        case .nodePass:
            targets = url.targets.map { TargetRow(host: $0.host, port: $0.port.map(String.init) ?? "") }
            if targets.isEmpty { targets = [TargetRow(host: "", port: "")] }
            carriers = []
            usesCarrierPaths = false
        case .openCtrl:
            carriers = url.carriers.map { CarrierRow(kind: $0.kind, port: $0.port.map(String.init) ?? "") }
            usesCarrierPaths = !carriers.isEmpty
            targets = []
        }
        rawText = url.string
        rawError = nil
    }

    private func applyRoleDefaults() {
        switch flavor {
        case .nodePass:
            if targets.isEmpty { targets = [TargetRow(host: "", port: "")] }
        case .openCtrl:
            if role == .portal, tunnelHost.isEmpty { tunnelHost = "*" }
        }
    }

    // MARK: Composition

    var composed: InstanceURL {
        var url = InstanceURL(role: role)
        url.credential = credential.isEmpty ? nil : credential
        url.tunnel = HostPort(host: tunnelHost.trimmingCharacters(in: .whitespaces), port: Int(tunnelPort.trimmingCharacters(in: .whitespaces)))
        switch flavor {
        case .nodePass:
            url.targets = targets.map { HostPort(host: $0.host.trimmingCharacters(in: .whitespaces), port: Int($0.port.trimmingCharacters(in: .whitespaces))) }
        case .openCtrl:
            if usesCarrierPaths {
                url.carriers = carriers.map { Carrier(kind: $0.kind, port: Int($0.port.trimmingCharacters(in: .whitespaces))) }
                url.tunnel.port = nil
            }
        }
        url.parameters = parameters.filter { !$0.key.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { URLParameter($0.key.trimmingCharacters(in: .whitespaces), $0.value.trimmingCharacters(in: .whitespaces)) }
        url.fragment = fragment
        return url
    }

    /// The URL that would be sent to the master.
    var urlString: String {
        switch inputMode {
        case .structured: composed.string
        case .text: rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    /// Parsed form of the current input, if valid.
    var currentURL: InstanceURL? {
        switch inputMode {
        case .structured: composed
        case .text: try? InstanceURL(parsing: rawText)
        }
    }

    var issues: [ValidationIssue] {
        guard let currentURL else {
            return [ValidationIssue(severity: .error, field: .general, message: rawError ?? "The URL could not be parsed.")]
        }
        var result = currentURL.validate()
        if inputMode == .text, currentURL.role.flavor != flavor {
            result.insert(ValidationIssue(severity: .error, field: .role, message: "This master manages \(flavor.roles.map(\.rawValue).joined(separator: "/")) instances."), at: 0)
        }
        return result
    }

    var hasErrors: Bool { issues.contains { $0.severity == .error } }

    var hasChanges: Bool {
        guard original != nil else { return true }
        return urlString != originalURL || alias != originalAlias || autoRestart != originalRestart
    }

    var canSave: Bool { !hasErrors && hasChanges && !isSaving }

    var urlChanged: Bool { original != nil && urlString != originalURL }

    private(set) var isSaving = false

    // MARK: Mode switching

    func setInputMode(_ mode: InputMode) {
        guard mode != inputMode else { return }
        switch mode {
        case .text:
            rawText = composed.string
            rawError = nil
            inputMode = .text
        case .structured:
            do {
                let parsed = try InstanceURL(parsing: rawText)
                guard parsed.role.flavor == flavor else {
                    rawError = "Scheme “\(parsed.role.rawValue)” does not belong to this master. Use \(flavor.roles.map { $0.rawValue + "://" }.joined(separator: " or "))."
                    return
                }
                load(parsed)
                inputMode = .structured
            } catch {
                rawError = error.localizedDescription
            }
        }
    }

    func validateRawText() {
        do {
            _ = try InstanceURL(parsing: rawText)
            rawError = nil
        } catch {
            rawError = error.localizedDescription
        }
    }

    // MARK: Parameters

    func spec(for key: String) -> ParameterSpec? {
        ParameterCatalog.spec(key: key, role: role) ?? ParameterCatalog.spec(key: key, flavor: flavor)
    }

    func isApplicable(_ key: String) -> Bool {
        if ParameterCatalog.spec(key: key, role: role) != nil { return true }
        // Unknown keys are passed through; only keys known for another role are inapplicable.
        return ParameterCatalog.spec(key: key, flavor: flavor) == nil
    }

    var availableSpecs: [ParameterSpec] {
        let present = Set(parameters.map(\.key))
        return ParameterCatalog.specs(for: role).filter { !present.contains($0.key) }
    }

    var inapplicableRows: [ParameterRow] {
        parameters.filter { !isApplicable($0.key) }
    }

    func add(_ spec: ParameterSpec) {
        guard !parameters.contains(where: { $0.key == spec.key }) else { return }
        let initial: String
        switch spec.kind {
        case .options(let options): initial = spec.defaultValue ?? options.first?.value ?? ""
        case .boolean: initial = spec.defaultValue == "1" ? "0" : "1"
        case .bitSet: initial = ""
        default: initial = spec.defaultValue ?? ""
        }
        parameters.append(ParameterRow(key: spec.key, value: initial))
    }

    func addCustom(key: String, value: String = "") {
        let trimmed = key.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !parameters.contains(where: { $0.key == trimmed }) else { return }
        parameters.append(ParameterRow(key: trimmed, value: value))
    }

    func remove(_ id: ParameterRow.ID) {
        parameters.removeAll { $0.id == id }
    }

    func removeInapplicable() {
        parameters.removeAll { !isApplicable($0.key) }
    }

    // MARK: Endpoints

    func addTarget() {
        targets.append(TargetRow(host: "", port: ""))
    }

    func removeTarget(_ id: TargetRow.ID) {
        guard targets.count > 1 else { return }
        targets.removeAll { $0.id == id }
    }

    func addCarrier() {
        let kinds = Set(carriers.map(\.kind))
        let next: Carrier.Kind = kinds.contains(.tcp) ? .udp : .tcp
        carriers.append(CarrierRow(kind: next, port: ""))
    }

    func removeCarrier(_ id: CarrierRow.ID) {
        carriers.removeAll { $0.id == id }
    }

    func setRole(_ newRole: InstanceRole) {
        role = newRole
        applyRoleDefaults()
    }

    /// 32 lowercase hexadecimal characters, as Nowhere expects.
    func generateSharedKey() {
        credential = (0..<16).map { _ in String(format: "%02x", UInt8.random(in: .min ... .max)) }.joined()
    }

    // MARK: Saving

    @discardableResult
    func save(to session: MasterSession) async throws -> Instance {
        isSaving = true
        defer { isSaving = false }
        let url = urlString
        let trimmedAlias = alias.trimmingCharacters(in: .whitespacesAndNewlines)

        if let original {
            var latest = original
            if url != originalURL {
                latest = try await session.replaceURL(url, for: original.id)
            }
            var patch = InstancePatch()
            if trimmedAlias != originalAlias, !trimmedAlias.isEmpty { patch.alias = trimmedAlias }
            if autoRestart != originalRestart { patch.restart = autoRestart }
            if !patch.isEmpty {
                latest = try await session.patch(patch, for: original.id)
            }
            return latest
        } else {
            var created = try await session.create(url: url, alias: trimmedAlias.isEmpty ? nil : trimmedAlias)
            if !autoRestart {
                created = try await session.patch(InstancePatch(restart: false), for: created.id)
            }
            return created
        }
    }
}
