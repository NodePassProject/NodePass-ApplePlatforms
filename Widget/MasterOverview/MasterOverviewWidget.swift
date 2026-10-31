//
//  MasterOverviewWidget.swift
//  NodePass Widget
//
//  Host metrics and instances of one master, in every size from small to extra large.
//

import WidgetKit
import SwiftUI

struct MasterOverviewEntry: TimelineEntry {
    enum Content {
        case report(MasterReport)
        /// Nothing to load, e.g. no master chosen yet.
        case message(String)
    }

    let date: Date
    let content: Content
}

struct MasterOverviewProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> MasterOverviewEntry {
        MasterOverviewEntry(date: .now, content: .report(.demo))
    }

    func snapshot(for configuration: MasterOverviewConfigurationIntent, in context: Context) async -> MasterOverviewEntry {
        if context.isPreview { return placeholder(in: context) }
        return await entry(for: configuration.master)
    }

    func timeline(for configuration: MasterOverviewConfigurationIntent, in context: Context) async -> Timeline<MasterOverviewEntry> {
        let entry = await entry(for: configuration.master)
        return Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(15 * 60)))
    }

    private func entry(for entity: MasterEntity?) async -> MasterOverviewEntry {
        guard let entity else {
            return MasterOverviewEntry(date: .now, content: .message("Choose a master in the widget settings."))
        }
        guard let snapshot = try? MasterStore.snapshots(ids: [entity.id]).first else {
            return MasterOverviewEntry(date: .now, content: .message("This master was removed."))
        }
        return MasterOverviewEntry(date: .now, content: .report(await MasterReport.load(snapshot)))
    }
}

struct MasterOverviewWidget: Widget {
    let kind = "MasterOverviewWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: MasterOverviewConfigurationIntent.self, provider: MasterOverviewProvider()) { entry in
            MasterOverviewWidgetView(entry: entry)
        }
        .configurationDisplayName("Master Overview")
        .description("Host metrics and instances of a master.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge])
    }
}

#Preview(as: .systemMedium) {
    MasterOverviewWidget()
} timeline: {
    MasterOverviewEntry(date: .now, content: .report(.demo))
    MasterOverviewEntry(date: .now, content: .report(MasterReport.demoFleet[3]))
}

#Preview(as: .systemLarge) {
    MasterOverviewWidget()
} timeline: {
    MasterOverviewEntry(date: .now, content: .report(.demo))
}

#Preview(as: .systemExtraLarge) {
    MasterOverviewWidget()
} timeline: {
    MasterOverviewEntry(date: .now, content: .report(.demo))
}
