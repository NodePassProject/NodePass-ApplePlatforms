//
//  CreateInstanceIntent.swift
//  NodePass
//
//  Creates an instance from a URL, the way the editor's raw mode does: the URL is parsed and
//  validated against the master's flavor before the master sees it.
//

import AppIntents

struct CreateInstanceIntent: nonisolated AppIntent {
    nonisolated static let title: LocalizedStringResource = "Create Instance"
    nonisolated static let description = IntentDescription(
        "Creates an instance on a master from a NodePass or Nowhere URL.",
        categoryName: "Instances",
        resultValueName: "Instance"
    )

    nonisolated static var parameterSummary: some ParameterSummary {
        Summary("Create instance from \(\.$url) on \(\.$master)") {
            \.$alias
        }
    }

    @Parameter(title: "URL", requestValueDialog: "What is the instance URL?")
    var url: String

    @Parameter(title: "Master", requestValueDialog: "On which master?")
    var master: MasterEntity

    @Parameter(title: "Alias")
    var alias: String?

    @Dependency private var model: IntentModel

    nonisolated init() {}

    init(url: String, master: MasterEntity, alias: String? = nil) {
        self.url = url
        self.master = master
        self.alias = alias
    }

    @MainActor
    func perform() async throws -> some ReturnsValue<InstanceEntity> & ProvidesDialog {
        let snapshot = try model.master(for: master)
        let parsed = try Self.validate(url: url, for: snapshot)
        let trimmedAlias = alias?.trimmingCharacters(in: .whitespacesAndNewlines)
        let created = try await model.create(url: parsed.description, alias: trimmedAlias?.isEmpty == false ? trimmedAlias : nil, on: snapshot)
        let entity = InstanceEntity(created, master: MasterEntity(snapshot))
        return .result(value: entity, dialog: "Created \(entity.name) on \(entity.master.name).")
    }

    /// Parses the URL and rejects what the master would reject, with the editor's wording.
    nonisolated static func validate(url text: String, for master: MasterSnapshot) throws(NodePassIntentError) -> InstanceURL {
        let parsed: InstanceURL
        do {
            parsed = try InstanceURL(parsing: text)
        } catch {
            throw .invalidInstanceURL(reason: error.localizedDescription)
        }
        if let masterFlavor = master.flavor, let urlFlavor = parsed.flavor, masterFlavor != urlFlavor {
            throw .flavorMismatch(role: parsed.role.title, master: master.name, flavor: masterFlavor.title)
        }
        let errors = parsed.validate().filter { $0.severity == .error }
        if !errors.isEmpty {
            throw .invalidInstanceURL(reason: errors.map(\.message).joined(separator: " "))
        }
        return parsed
    }
}
