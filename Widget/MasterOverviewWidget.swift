//
//  MasterOverviewWidget.swift
//  NodePass Widget
//
//  Host metrics and instance counts of one master.
//

import WidgetKit
import SwiftUI
import AppIntents
import SwiftData

// MARK: - Entity

struct MasterEntity: AppEntity {
    let id: String
    let name: String

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Master"
    static let defaultQuery = MasterQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct MasterQuery: EntityQuery {
    func entities(for identifiers: [MasterEntity.ID]) async throws -> [MasterEntity] {
        try await MasterStore.snapshots().filter { identifiers.contains($0.id) }.map { MasterEntity(id: $0.id, name: $0.name) }
    }

    func suggestedEntities() async throws -> [MasterEntity] {
        try await MasterStore.snapshots().map { MasterEntity(id: $0.id, name: $0.name) }
    }

    func defaultResult() async -> MasterEntity? {
        try? await suggestedEntities().first
    }
}

/// Reads masters from the shared SwiftData store.
enum MasterStore {
    @MainActor
    static func snapshots() throws -> [MasterSnapshot] {
        let container = try NPData.makeContainer()
        let context = container.mainContext
        let descriptor = FetchDescriptor<Server>(sortBy: [SortDescriptor(\.timestamp)])
        return try context.fetch(descriptor).map(\.snapshot)
    }

    @MainActor
    static func snapshot(id: String) throws -> MasterSnapshot? {
        try snapshots().first { $0.id == id }
    }
}

// MARK: - Intents

struct MasterOverviewConfigurationIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Master Overview"
    static let description = IntentDescription("Shows host metrics and instance counts of a master.")

    @Parameter(title: "Master")
    var master: MasterEntity?

    init() {}

    init(master: MasterEntity) {
        self.master = master
    }
}

struct RefreshWidgetIntent: AppIntent {
    static let title: LocalizedStringResource = "Refresh"
    static let description = IntentDescription("Reload the widget's data.")

    func perform() async throws -> some IntentResult {
        .result()
    }
}

// MARK: - Timeline

struct MasterEntry: TimelineEntry {
    struct Payload {
        var id: String
        var name: String
        var info: MasterInfo
        var running: Int
        var stopped: Int
        var errors: Int
    }

    let date: Date
    let payload: Payload?
    let message: String
}

struct MasterOverviewProvider: AppIntentTimelineProvider {
    typealias Entry = MasterEntry
    typealias Intent = MasterOverviewConfigurationIntent

    private static var demo: MasterEntry {
        var info = MasterInfo()
        info.cpuUsage = 23
        info.memoryTotal = 4 * 1024 * 1024 * 1024
        info.memoryUsed = 1_700_000_000
        info.swapTotal = 1024 * 1024 * 1024
        info.swapUsed = 120_000_000
        info.networkReceived = 120_000_000_000
        info.networkTransmitted = 48_000_000_000
        info.uptime = 86_400 * 3 + 3600 * 5
        info.version = "1.9.0"
        info.os = "linux"
        info.architecture = "amd64"
        return MasterEntry(date: .now, payload: .init(id: "demo", name: "Tokyo Edge", info: info, running: 6, stopped: 1, errors: 0), message: "")
    }

    func placeholder(in context: Context) -> MasterEntry { Self.demo }

    func snapshot(for configuration: MasterOverviewConfigurationIntent, in context: Context) async -> MasterEntry {
        if context.isPreview { return Self.demo }
        return await load(configuration.master)
    }

    func timeline(for configuration: MasterOverviewConfigurationIntent, in context: Context) async -> Timeline<MasterEntry> {
        let entry = await load(configuration.master)
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: .now) ?? .now.addingTimeInterval(900)
        return Timeline(entries: [entry], policy: .after(next))
    }

    private func load(_ entity: MasterEntity?) async -> MasterEntry {
        guard let entity else {
            return MasterEntry(date: .now, payload: nil, message: "Choose a master in the widget settings.")
        }
        guard let snapshot = try? MasterStore.snapshot(id: entity.id), let credentials = snapshot.credentials else {
            return MasterEntry(date: .now, payload: nil, message: "Master not found.")
        }
        let client = MasterClient(credentials: credentials)
        do {
            let info = try await client.info()
            let instances = (try? await client.instances())?.filter { !$0.isAPIKeyHolder } ?? []
            let payload = MasterEntry.Payload(
                id: snapshot.id,
                name: snapshot.name,
                info: info,
                running: instances.filter { $0.status == .running }.count,
                stopped: instances.filter { $0.status == .stopped }.count,
                errors: instances.filter { $0.status == .error }.count)
            return MasterEntry(date: .now, payload: payload, message: "")
        } catch {
            return MasterEntry(date: .now, payload: nil, message: APIError.wrap(error).shortDescription)
        }
    }
}

// MARK: - Views

struct MasterOverviewWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: MasterEntry

    var body: some View {
        Group {
            if let payload = entry.payload {
                switch family {
                case .systemSmall: small(payload)
                default: medium(payload)
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "server.rack")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text(entry.message)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                    Button(intent: RefreshWidgetIntent()) {
                        Label("Retry", systemImage: "arrow.clockwise")
                            .font(.caption)
                    }
                }
            }
        }
        .containerBackground(.background, for: .widget)
        .widgetURL(entry.payload.flatMap { URL(string: "np://master?id=\($0.id)") })
    }

    private func small(_ payload: MasterEntry.Payload) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(payload.name)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
            Spacer(minLength: 0)
            HStack {
                gauge("CPU", value: payload.info.cpuRatio, label: payload.info.cpuUsage < 0 ? "—" : "\(payload.info.cpuUsage)%", tint: .blue, size: 46)
                Spacer()
                gauge("Mem", value: payload.info.memoryRatio, label: Format.percent(payload.info.memoryRatio), tint: .purple, size: 46)
            }
            Spacer(minLength: 0)
            counts(payload)
        }
    }

    private func medium(_ payload: MasterEntry.Payload) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(payload.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                if payload.info.uptime > 0 {
                    Label(Format.duration(seconds: payload.info.uptime, compact: true), systemImage: "power")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(intent: RefreshWidgetIntent()) {
                    HStack(spacing: 3) {
                        Text(entry.date, style: .time)
                        Image(systemName: "arrow.clockwise")
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            HStack(alignment: .top) {
                gauge("CPU", value: payload.info.cpuRatio, label: payload.info.cpuUsage < 0 ? "—" : "\(payload.info.cpuUsage)%", tint: .blue, size: 50)
                Spacer()
                gauge("Memory", value: payload.info.memoryRatio, label: Format.percent(payload.info.memoryRatio), tint: .purple, size: 50)
                Spacer()
                gauge("Swap", value: payload.info.swapRatio, label: payload.info.swapTotal == 0 ? "—" : Format.percent(payload.info.swapRatio), tint: .teal, size: 50)
                Spacer()
                let total = Double(payload.info.networkReceived + payload.info.networkTransmitted)
                Gauge(value: total == 0 ? 0 : Double(payload.info.networkReceived) / total) {
                    Text("Network")
                } currentValueLabel: {
                    EmptyView()
                }
                .gaugeStyle(SplitRingGaugeStyle(
                    primaryText: "↓ \(Format.bytes(payload.info.networkReceived, decimals: 0))",
                    secondaryText: "↑ \(Format.bytes(payload.info.networkTransmitted, decimals: 0))",
                    primaryTint: .blue, secondaryTint: .orange, size: 50))
            }
            counts(payload)
        }
    }

    private func gauge(_ title: String, value: Double, label: String, tint: Color, size: CGFloat) -> some View {
        Gauge(value: value) {
            Text(title)
        } currentValueLabel: {
            Text(label)
        }
        .gaugeStyle(RingGaugeStyle(tint: tint, size: size))
    }

    private func counts(_ payload: MasterEntry.Payload) -> some View {
        HStack(spacing: 8) {
            Label("\(payload.running)", systemImage: "play.circle.fill").foregroundStyle(.green)
            Label("\(payload.stopped)", systemImage: "stop.circle.fill").foregroundStyle(.secondary)
            if payload.errors > 0 {
                Label("\(payload.errors)", systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red)
            }
            Spacer()
            if !payload.info.version.isEmpty {
                Text(payload.info.version)
                    .foregroundStyle(.tertiary)
            }
        }
        .font(.caption2.monospacedDigit())
    }
}

struct MasterOverviewWidget: Widget {
    let kind = "MasterOverviewWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: MasterOverviewConfigurationIntent.self, provider: MasterOverviewProvider()) { entry in
            MasterOverviewWidgetView(entry: entry)
        }
        .configurationDisplayName("Master Overview")
        .description("Host metrics and instance counts of a master.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
