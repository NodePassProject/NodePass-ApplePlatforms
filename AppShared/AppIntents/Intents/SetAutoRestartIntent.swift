//
//  SetAutoRestartIntent.swift
//  NodePass
//
//  Flips the master-side auto-restart policy of an instance.
//

import AppIntents

struct SetAutoRestartIntent: nonisolated AppIntent {
    nonisolated static let title: LocalizedStringResource = "Set Auto-restart"
    nonisolated static let description = IntentDescription(
        "Turns the auto-restart policy of an instance on or off. The master restarts an instance with the policy on whenever it exits.",
        categoryName: "Instances",
        resultValueName: "Instance"
    )

    nonisolated static var parameterSummary: some ParameterSummary {
        Summary("Turn auto-restart \(\.$isEnabled) for \(\.$instance)")
    }

    @Parameter(title: "Instance", requestValueDialog: "Which instance?")
    var instance: InstanceEntity

    @Parameter(title: "Auto-restart", displayName: .init(true: "on", false: "off"))
    var isEnabled: Bool

    @Dependency private var model: IntentModel

    nonisolated init() {}

    init(instance: InstanceEntity, isEnabled: Bool) {
        self.instance = instance
        self.isEnabled = isEnabled
    }

    @MainActor
    func perform() async throws -> some ReturnsValue<InstanceEntity> & ProvidesDialog {
        let master = try model.master(instance.id.masterID)
        let updated = InstanceEntity(try await model.setRestartPolicy(isEnabled, on: instance.id.instanceID, of: master), master: MasterEntity(master))
        return .result(value: updated, dialog: "Auto-restart is now \(isEnabled ? "on" : "off") for \(updated.name).")
    }
}
