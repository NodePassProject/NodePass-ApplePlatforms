//
//  DeleteInstanceIntent.swift
//  NodePass
//
//  Removes an instance from its master after confirmation. Deleting is final on the master side,
//  so the intent asks even when run from Siri.
//

import AppIntents
import CoreSpotlight

struct DeleteInstanceIntent: nonisolated AppIntent {
    nonisolated static let title: LocalizedStringResource = "Delete Instance"
    nonisolated static let description = IntentDescription("Stops an instance and removes it from its master. This cannot be undone.", categoryName: "Instances")

    nonisolated static var parameterSummary: some ParameterSummary {
        Summary("Delete \(\.$instance)")
    }

    @Parameter(title: "Instance", requestValueDialog: "Which instance?")
    var instance: InstanceEntity

    @Dependency private var model: IntentModel

    nonisolated init() {}

    init(instance: InstanceEntity) {
        self.instance = instance
    }

    @MainActor
    func perform() async throws -> some ProvidesDialog {
        try await requestConfirmation(
            actionName: .custom(acceptLabel: "Delete", acceptAlternatives: [], denyLabel: "Cancel", denyAlternatives: [], destructive: true),
            dialog: "Delete \(instance.name) from \(instance.master.name)? The instance is stopped and removed from the master."
        )
        let master = try model.master(instance.id.masterID)
        try await model.delete(instance.id.instanceID, of: master)
        try? await CSSearchableIndex.default().deleteAppEntities(identifiedBy: [instance.id], ofType: InstanceEntity.self)
        return .result(dialog: "Deleted \(instance.name) from \(master.name).")
    }
}
