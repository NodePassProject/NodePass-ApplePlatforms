//
//  FleetWidget.swift
//  NodePass Widget
//
//  The health of several masters at once — on the Mac desktop, the counterpart of the menu bar
//  item.
//

import WidgetKit
import SwiftUI
import AppIntents

struct FleetEntry: TimelineEntry {
    let date: Date
    let reports: [MasterReport]
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
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge])
    }
}

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
