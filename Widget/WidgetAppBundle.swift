//
//  WidgetAppBundle.swift
//  NodePass Widget
//

import WidgetKit
import SwiftUI
import AppIntents

extension MasterStore {
    /// The one store of this process: the timeline providers read it directly, and the master
    /// picker in widget settings reaches it through `MasterQuery`'s dependency.
    static let widget = MasterStore()
}

@main
struct WidgetAppBundle: WidgetBundle {
    init() {
        // Registered as an existing object: `@Dependency` values are resolved inside the intent
        // flow, not created there, so the store never has to be made off the main actor.
        let store = MasterStore.widget
        AppDependencyManager.shared.add(dependency: store)
    }

    var body: some Widget {
        MasterOverviewWidget()
        FleetWidget()
    }
}
