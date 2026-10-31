//
//  WidgetIntents.swift
//  NodePass Widget
//

import AppIntents

struct MasterOverviewConfigurationIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Master Overview"
    static let description = IntentDescription("Shows host metrics and instances of a master.")

    @Parameter(title: "Master")
    var master: MasterEntity?

    init() {}

    init(master: MasterEntity) {
        self.master = master
    }
}

struct FleetConfigurationIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Masters"
    static let description = IntentDescription("Shows the health of several masters at once.")

    /// Masters to show, in this order. Empty shows every enabled master.
    @Parameter(title: "Masters")
    var masters: [MasterEntity]?

    init() {}
}

struct RefreshWidgetIntent: AppIntent {
    static let title: LocalizedStringResource = "Refresh"
    static let description = IntentDescription("Reload the widget's data.")

    func perform() async throws -> some IntentResult {
        // Running any intent from a widget reloads its timeline.
        .result()
    }
}
