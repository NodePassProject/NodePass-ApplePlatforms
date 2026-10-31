//
//  GetInstanceStatusIntent.swift
//  NodePass
//
//  "Is my-tunnel running in NodePass?": the instance as the master reports it right now.
//

import AppIntents

struct GetInstanceStatusIntent: nonisolated AppIntent {
    nonisolated static let title: LocalizedStringResource = "Get Instance Status"
    nonisolated static let description = IntentDescription(
        "Reports whether an instance is running, with its connections and traffic.",
        categoryName: "Instances",
        resultValueName: "Instance"
    )

    nonisolated static var parameterSummary: some ParameterSummary {
        Summary("Get status of \(\.$instance)")
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
        let current = try await model.refreshed(instance)
        return .result(value: current, dialog: Self.dialog(for: current), snippetIntent: InstanceSnippetIntent(instance: current))
    }

    nonisolated static func dialog(for entity: InstanceEntity) -> IntentDialog {
        let instance = entity.instance
        let traffic = "\(Format.bytes(instance.totalReceived)) received, \(Format.bytes(instance.totalTransmitted)) transmitted"
        return IntentDialog(full: statusText(for: entity), supporting: "\(entity.role.title) on \(entity.master.name) · \(traffic)")
    }

    /// The one sentence Siri speaks.
    nonisolated static func statusText(for entity: InstanceEntity) -> LocalizedStringResource {
        let instance = entity.instance
        switch instance.status {
        case .running:
            return "\(entity.name) is running with \(instance.tcpConnections) TCP and \(instance.udpConnections) UDP connections."
        case .stopped:
            return "\(entity.name) is stopped."
        case .error:
            return "\(entity.name) is in an error state."
        case .other(let raw):
            return raw.isEmpty ? "\(entity.name) has an unknown status." : "\(entity.name) reports status “\(raw)”."
        }
    }
}

extension GetInstanceStatusIntent: nonisolated PredictableIntent {
    nonisolated static var predictionConfiguration: some IntentPredictionConfiguration {
        IntentPrediction(parameters: \.$instance) { instance in
            DisplayRepresentation(
                title: "Get status of \(instance.name)",
                subtitle: "\(instance.master.name)",
                image: instance.displayRepresentation.image
            )
        }
    }
}
