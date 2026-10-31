//
//  GetMasterStatusIntent.swift
//  NodePass
//
//  "Check Home Lab in NodePass": whether a master answers, what it runs, and how its host is doing.
//

import AppIntents

struct GetMasterStatusIntent: nonisolated AppIntent {
    nonisolated static let title: LocalizedStringResource = "Get Master Status"
    nonisolated static let description = IntentDescription(
        "Checks whether a master answers and counts its running, stopped and failing instances.",
        categoryName: "Masters",
        resultValueName: "Master Status"
    )

    nonisolated static var parameterSummary: some ParameterSummary {
        Summary("Get status of \(\.$master)")
    }

    @Parameter(title: "Master", requestValueDialog: "Which master?")
    var master: MasterEntity

    @Dependency private var model: IntentModel

    nonisolated init() {}

    init(master: MasterEntity) {
        self.master = master
    }

    @MainActor
    func perform() async throws -> some ReturnsValue<MasterStatus> & ProvidesDialog & ShowsSnippetIntent {
        let snapshot = try model.master(for: master)
        let current = MasterEntity(snapshot)
        let report = MasterStatus.Report(master: current, health: await model.health(of: snapshot))
        return .result(value: MasterStatus(report), dialog: report.dialog, snippetIntent: MasterStatusSnippetIntent(master: current))
    }
}

extension GetMasterStatusIntent: nonisolated PredictableIntent {
    nonisolated static var predictionConfiguration: some IntentPredictionConfiguration {
        IntentPrediction(parameters: \.$master) { master in
            DisplayRepresentation(title: "Get status of \(master.name)", image: master.displayRepresentation.image)
        }
    }
}
