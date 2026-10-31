//
//  MasterOverviewWidget.swift
//  NodePass Widget
//
//  Host metrics and instances of one master: every size from small to extra large on the Home
//  Screen and the desktop, and the accessory sizes on the Lock Screen and Apple Watch.
//

import WidgetKit
import SwiftUI
import AppIntents

struct MasterOverviewEntry: TimelineEntry {
    enum Content {
        case report(MasterReport)
        /// Nothing to load, e.g. no master chosen yet.
        case message(String)
    }

    let date: Date
    let content: Content

    /// Masters in trouble come forward in the Smart Stack.
    var relevance: TimelineEntryRelevance? {
        guard case .report(let report) = content else { return nil }
        if !report.isReachable { return TimelineEntryRelevance(score: 2) }
        return TimelineEntryRelevance(score: report.errors > 0 ? 1 : 0)
    }
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

    /// Watch faces offer configured complications rather than a configuration screen: one per
    /// enabled master.
    func recommendations() -> [AppIntentRecommendation<MasterOverviewConfigurationIntent>] {
        let masters = (try? MasterStore.widget.snapshots().filter(\.isEnabled)) ?? []
        return masters.map { master in
            AppIntentRecommendation(intent: MasterOverviewConfigurationIntent(master: MasterEntity(master)), description: Text(master.name))
        }
    }

    private func entry(for entity: MasterEntity?) async -> MasterOverviewEntry {
        guard let entity else {
            return MasterOverviewEntry(date: .now, content: .message("Choose a master in the widget settings."))
        }
        guard let snapshot = try? MasterStore.widget.snapshot(id: entity.id) else {
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
        .supportedFamilies(WidgetFamily.nodePassSupported)
    }
}

#if !os(macOS)
#Preview(as: .accessoryRectangular) {
    MasterOverviewWidget()
} timeline: {
    MasterOverviewEntry(date: .now, content: .report(.demo))
    MasterOverviewEntry(date: .now, content: .report(MasterReport.demoFleet[2]))
    MasterOverviewEntry(date: .now, content: .report(MasterReport.demoFleet[3]))
}

#Preview(as: .accessoryCircular) {
    MasterOverviewWidget()
} timeline: {
    MasterOverviewEntry(date: .now, content: .report(.demo))
    MasterOverviewEntry(date: .now, content: .report(MasterReport.demoFleet[3]))
}

#Preview(as: .accessoryInline) {
    MasterOverviewWidget()
} timeline: {
    MasterOverviewEntry(date: .now, content: .report(.demo))
}
#endif

#if os(watchOS)
#Preview(as: .accessoryCorner) {
    MasterOverviewWidget()
} timeline: {
    MasterOverviewEntry(date: .now, content: .report(.demo))
    MasterOverviewEntry(date: .now, content: .report(MasterReport.demoFleet[3]))
}
#endif

#if !os(watchOS)
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
#endif
