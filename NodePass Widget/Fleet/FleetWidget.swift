//
//  FleetWidget.swift
//  NodePass Widget
//
//  The health of several masters at once — on the Mac desktop, the counterpart of the menu bar
//  item; on Apple Watch, the complication that says whether everything is up.
//

import WidgetKit
import SwiftUI
import AppIntents

struct FleetEntry: TimelineEntry {
    let date: Date
    let reports: [MasterReport]

    /// The more masters are down or failing, the further forward the widget comes in the Smart Stack.
    var relevance: TimelineEntryRelevance? {
        let unreachable = reports.filter { !$0.isReachable }.count
        let errors = reports.reduce(0) { $0 + $1.errors }
        return TimelineEntryRelevance(score: Float(unreachable * 2 + errors))
    }
}

struct FleetProvider: AppIntentTimelineProvider {
    /// Bounds the network work of one reload; no layout shows more.
    private static let maximumMasters = 12

    func placeholder(in context: Context) -> FleetEntry {
        FleetEntry(date: .now, reports: MasterReport.demoFleet)
    }

    func snapshot(for configuration: FleetConfigurationIntent, in context: Context) async -> FleetEntry {
        if context.isPreview { return placeholder(in: context) }
        return await entry(for: configuration)
    }

    func timeline(for configuration: FleetConfigurationIntent, in context: Context) async -> Timeline<FleetEntry> {
        let entry = await entry(for: configuration)
        return Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(15 * 60)))
    }

    /// Watch faces offer configured complications rather than a configuration screen.
    func recommendations() -> [AppIntentRecommendation<FleetConfigurationIntent>] {
        [AppIntentRecommendation(intent: FleetConfigurationIntent(), description: Text("All Masters"))]
    }

    private func entry(for configuration: FleetConfigurationIntent) async -> FleetEntry {
        let chosen = configuration.masters ?? []
        let snapshots: [MasterSnapshot]
        if chosen.isEmpty {
            snapshots = (try? MasterStore.widget.snapshots().filter(\.isEnabled)) ?? []
        } else {
            snapshots = (try? MasterStore.widget.snapshots(ids: chosen.map(\.id))) ?? []
        }
        let reports = await MasterReport.load(Array(snapshots.prefix(Self.maximumMasters)))
        return FleetEntry(date: .now, reports: reports)
    }
}

struct FleetWidget: Widget {
    let kind = "FleetWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: FleetConfigurationIntent.self, provider: FleetProvider()) { entry in
            FleetWidgetView(entry: entry)
        }
        .configurationDisplayName("Masters")
        .description("The health of all your masters at a glance.")
        .supportedFamilies(WidgetFamily.nodePassSupported)
    }
}

#if !os(macOS)
#Preview(as: .accessoryRectangular) {
    FleetWidget()
} timeline: {
    FleetEntry(date: .now, reports: MasterReport.demoFleet)
    FleetEntry(date: .now, reports: Array(MasterReport.demoFleet.prefix(2)))
}

#Preview(as: .accessoryCircular) {
    FleetWidget()
} timeline: {
    FleetEntry(date: .now, reports: MasterReport.demoFleet)
}

#Preview(as: .accessoryInline) {
    FleetWidget()
} timeline: {
    FleetEntry(date: .now, reports: MasterReport.demoFleet)
    FleetEntry(date: .now, reports: Array(MasterReport.demoFleet.prefix(2)))
}
#endif

#if os(watchOS)
#Preview(as: .accessoryCorner) {
    FleetWidget()
} timeline: {
    FleetEntry(date: .now, reports: MasterReport.demoFleet)
}
#endif

#if !os(watchOS)
#Preview(as: .systemSmall) {
    FleetWidget()
} timeline: {
    FleetEntry(date: .now, reports: MasterReport.demoFleet)
}

#Preview(as: .systemLarge) {
    FleetWidget()
} timeline: {
    FleetEntry(date: .now, reports: MasterReport.demoFleet)
}

#Preview(as: .systemExtraLarge) {
    FleetWidget()
} timeline: {
    FleetEntry(date: .now, reports: MasterReport.demoFleet)
}
#endif
