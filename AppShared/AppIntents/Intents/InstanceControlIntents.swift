//
//  InstanceControlIntents.swift
//  NodePass
//
//  Start, Stop, Restart and Reset Traffic as separate actions, so each has a verb of its own in
//  Shortcuts and a phrase of its own for Siri ("Restart my-tunnel in NodePass"). They share one
//  implementation, which also answers when nothing needs doing.
//

import AppIntents

struct StartInstanceIntent: nonisolated AppIntent {
    nonisolated static let title: LocalizedStringResource = "Start Instance"
    nonisolated static let description = IntentDescription("Starts an instance on its master.", categoryName: "Instances", resultValueName: "Instance")

    nonisolated static var parameterSummary: some ParameterSummary {
        Summary("Start \(\.$instance)")
    }

    @Parameter(title: "Instance", requestValueDialog: "Which instance?")
    var instance: InstanceEntity

    @Dependency private var model: IntentModel

    nonisolated init() {}

    init(instance: InstanceEntity) {
        self.instance = instance
    }

    @MainActor
    func perform() async throws -> some ReturnsValue<InstanceEntity> & ProvidesDialog & ShowsSnippetIntent {
        try await InstanceControl.perform(.start, on: instance, model: model)
    }
}

struct StopInstanceIntent: nonisolated AppIntent {
    nonisolated static let title: LocalizedStringResource = "Stop Instance"
    nonisolated static let description = IntentDescription("Stops an instance. Connections through it are closed.", categoryName: "Instances", resultValueName: "Instance")

    nonisolated static var parameterSummary: some ParameterSummary {
        Summary("Stop \(\.$instance)")
    }

    @Parameter(title: "Instance", requestValueDialog: "Which instance?")
    var instance: InstanceEntity

    @Dependency private var model: IntentModel

    nonisolated init() {}

    init(instance: InstanceEntity) {
        self.instance = instance
    }

    @MainActor
    func perform() async throws -> some ReturnsValue<InstanceEntity> & ProvidesDialog & ShowsSnippetIntent {
        try await InstanceControl.perform(.stop, on: instance, model: model)
    }
}

struct RestartInstanceIntent: nonisolated AppIntent {
    nonisolated static let title: LocalizedStringResource = "Restart Instance"
    nonisolated static let description = IntentDescription("Stops and starts an instance again. Connections are interrupted briefly.", categoryName: "Instances", resultValueName: "Instance")

    nonisolated static var parameterSummary: some ParameterSummary {
        Summary("Restart \(\.$instance)")
    }

    @Parameter(title: "Instance", requestValueDialog: "Which instance?")
    var instance: InstanceEntity

    @Dependency private var model: IntentModel

    nonisolated init() {}

    init(instance: InstanceEntity) {
        self.instance = instance
    }

    @MainActor
    func perform() async throws -> some ReturnsValue<InstanceEntity> & ProvidesDialog & ShowsSnippetIntent {
        try await InstanceControl.perform(.restart, on: instance, model: model)
    }
}

struct ResetInstanceTrafficIntent: nonisolated AppIntent {
    nonisolated static let title: LocalizedStringResource = "Reset Instance Traffic"
    nonisolated static let description = IntentDescription("Sets the cumulative traffic counters of an instance back to zero.", categoryName: "Instances", resultValueName: "Instance")

    nonisolated static var parameterSummary: some ParameterSummary {
        Summary("Reset traffic counters of \(\.$instance)")
    }

    @Parameter(title: "Instance", requestValueDialog: "Which instance?")
    var instance: InstanceEntity

    @Dependency private var model: IntentModel

    nonisolated init() {}

    init(instance: InstanceEntity) {
        self.instance = instance
    }

    @MainActor
    func perform() async throws -> some ReturnsValue<InstanceEntity> & ProvidesDialog & ShowsSnippetIntent {
        try await InstanceControl.perform(.reset, on: instance, model: model)
    }
}

/// The shared body of the control intents.
nonisolated enum InstanceControl {
    @MainActor
    static func perform(_ action: InstanceAction, on entity: InstanceEntity, model: IntentModel) async throws
        -> some ReturnsValue<InstanceEntity> & ProvidesDialog & ShowsSnippetIntent {
        let master = try model.master(entity.id.masterID)
        let masterEntity = MasterEntity(master)
        let current = try await model.instance(entity.id.instanceID, of: master)

        guard action.isApplicable(to: current.status) else {
            let unchanged = InstanceEntity(current, master: masterEntity)
            return .result(value: unchanged, dialog: unchangedDialog(action, unchanged), snippetIntent: InstanceSnippetIntent(instance: unchanged))
        }

        let updated = InstanceEntity(try await model.perform(action, on: current.id, of: master), master: masterEntity)
        return .result(value: updated, dialog: dialog(action, updated), snippetIntent: InstanceSnippetIntent(instance: updated))
    }

    /// What Siri says after the master accepted the action.
    static func dialog(_ action: InstanceAction, _ entity: InstanceEntity) -> IntentDialog {
        IntentDialog(
            full: completionText(action, entity),
            supporting: "\(entity.name) on \(entity.master.name) is \(entity.status.title.lowercased())."
        )
    }

    static func completionText(_ action: InstanceAction, _ entity: InstanceEntity) -> LocalizedStringResource {
        switch action {
        case .start: "Started \(entity.name)."
        case .stop: "Stopped \(entity.name)."
        case .restart: "Restarted \(entity.name)."
        case .reset: "Reset the traffic counters of \(entity.name)."
        }
    }

    /// What Siri says when the instance is already in the requested state.
    static func unchangedDialog(_ action: InstanceAction, _ entity: InstanceEntity) -> IntentDialog {
        IntentDialog(unchangedText(action, entity))
    }

    static func unchangedText(_ action: InstanceAction, _ entity: InstanceEntity) -> LocalizedStringResource {
        switch action {
        case .start: "\(entity.name) is already running."
        case .stop: "\(entity.name) is not running."
        case .restart, .reset: "\(entity.name) is unchanged."
        }
    }
}
