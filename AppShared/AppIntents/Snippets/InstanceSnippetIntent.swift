//
//  InstanceSnippetIntent.swift
//  NodePass
//
//  The card Siri and Shortcuts show for an instance. Its buttons run the control intents, and the
//  system performs this intent again afterwards, so the card shows the result.
//

import AppIntents
import SwiftUI

struct InstanceSnippetIntent: nonisolated SnippetIntent {
    nonisolated static let title: LocalizedStringResource = "Instance Snippet"

    @Parameter
    var instance: InstanceEntity

    @Dependency private var model: IntentModel

    nonisolated init() {}

    init(instance: InstanceEntity) {
        self.instance = instance
    }

    @MainActor
    func perform() async throws -> some IntentResult & ShowsSnippetView {
        // The result of a control intent is seconds old at most; otherwise ask the master again.
        let current = (try? await model.refreshed(instance, maxAge: 2)) ?? instance
        return .result(view: InstanceSnippetView(instance: current))
    }
}
