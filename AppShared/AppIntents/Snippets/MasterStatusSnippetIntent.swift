//
//  MasterStatusSnippetIntent.swift
//  NodePass
//
//  The card Siri and Shortcuts show for a master's health.
//

import AppIntents
import SwiftUI

struct MasterStatusSnippetIntent: nonisolated SnippetIntent {
    nonisolated static let title: LocalizedStringResource = "Master Status Snippet"

    @Parameter
    var master: MasterEntity

    @Dependency private var model: IntentModel

    nonisolated init() {}

    init(master: MasterEntity) {
        self.master = master
    }

    @MainActor
    func perform() async throws -> some IntentResult & ShowsSnippetView {
        let snapshot = try model.master(for: master)
        let current = MasterEntity(snapshot)
        let report = MasterStatus.Report(master: current, health: await model.health(of: snapshot, maxAge: 5))
        return .result(view: MasterStatusSnippetView(report: report))
    }
}
