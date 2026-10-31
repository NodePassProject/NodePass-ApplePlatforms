//
//  MasterOverviewView.swift
//  NodePass
//
//  Health, identity and administration of a master: a hero header in the health tint, then
//  panels for the host, the instances, the master's identity and its administration.
//
//  Like the instance detail, this view reads the session once and gives each panel only the
//  values it shows as an `Equatable` view, so a throughput tick redraws the throughput, not the
//  identity table beneath it.
//

import AppIntents
import SwiftUI

struct MasterOverviewView: View {
    @Environment(NavigationModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var session: MasterSession
    var master: Server
    var isSheet = false
    /// Share and Refresh join the Administration panel instead of the toolbar, for an inspector
    /// column that has no toolbar of its own. Always the case on macOS.
    var showsInlineActions = false

    private var usesInlineActions: Bool {
        #if os(macOS)
        true
        #else
        showsInlineActions
        #endif
    }

    @State private var aliasError: String?

    var body: some View {
        PanelScreen(tint: session.health.tint) {
            MasterHero(
                name: master.displayName,
                health: session.health,
                flavor: session.flavor,
                isEnabled: master.isEnabled,
                connection: session.connection,
                statusDetail: statusDetail,
                url: master.url,
                counts: session.hasLoadedInstances ? session.counts : nil,
                errorText: session.connection.isReachable ? nil : session.lastError?.localizedDescription)
                .equatable()
        } content: {
            if let error = session.infoError, session.info == nil {
                Panel {
                    InlineMessage(text: error.localizedDescription, style: .error)
                }
                .spansAllColumns()
            }
            if let info = session.info, info.hasSystemMetrics {
                HostPanel(info: info, history: session.infoHistory, networkRate: session.networkRate)
                    .equatable()
            }
            InstancesPanel(counts: session.counts, totals: session.totals, aggregateRate: session.aggregateRate)
                .equatable()
            if let info = session.info {
                IdentityPanel(info: info, masterID: session.masterID, flavorName: session.flavor.controllerName) { alias in
                    await commitAlias(alias)
                }
                .equatable()
            }
            AdministrationPanel(
                canRotateKey: session.connection.isReachable,
                showsShareAndRefresh: usesInlineActions,
                onRotateKey: { model.masterPendingKeyRotation = master },
                onEdit: { model.masterBeingEdited = master },
                onShare: { model.masterBeingShared = master },
                onRefresh: refresh)
                .equatable()
            if let notes = master.notes, !notes.isEmpty {
                NotesPanel(text: notes)
                    .equatable()
            }
        }
        .navigationTitle(master.displayName)
        .inlineNavigationTitle()
        .appEntityIdentifier(EntityIdentifier(for: MasterEntity.self, identifier: master.id))
        #if os(iOS)
        .toolbar {
            if isSheet {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", systemImage: "checkmark", role: .confirm) { dismiss() }
                }
            }
            if !showsInlineActions {
                ToolbarOverflowMenu {
                    Button("Edit Master", systemImage: "pencil") { model.masterBeingEdited = master }
                    Button("Share…", systemImage: "qrcode") { model.masterBeingShared = master }
                    Button("Refresh", systemImage: "arrow.clockwise") { refresh() }
                }
            }
        }
        #endif
        .alert("Could Not Rename Master", isPresented: Binding(isPresenting: $aliasError)) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(aliasError ?? "")
        }
    }

    private var statusDetail: String {
        switch session.connection {
        case .idle where !master.isEnabled:
            "Enable the master to connect."
        case .polling where session.lastError != nil:
            "\(session.connectionDetail) · stream: \(session.lastError?.shortDescription ?? "")"
        default:
            session.connectionDetail
        }
    }

    // MARK: Actions

    private func refresh() {
        Task {
            await session.refreshInfo()
            await session.refreshInstances()
        }
    }

    private func commitAlias(_ alias: String) async {
        guard alias != session.info?.alias else { return }
        do {
            try await session.updateMasterAlias(alias)
            Haptics.success()
        } catch {
            aliasError = APIError.wrap(error).localizedDescription
        }
    }
}

// MARK: - Hero

private struct MasterHero: View, Equatable {
    var name: String
    var health: MasterSession.Health
    var flavor: MasterFlavor
    var isEnabled: Bool
    var connection: ConnectionState
    var statusDetail: String
    var url: String
    /// Nil until the instance table has loaded.
    var counts: InstanceCounts?
    var errorText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.m) {
            HeroHeader(title: name) {
                StateBadge(title: health.title, tint: health.tint, systemImage: health.symbolName)
                Pill(text: flavor.title, tint: .accentColor, systemImage: flavor == .openCtrl ? "circle.hexagongrid" : "server.rack")
                if !isEnabled {
                    Pill(text: "Disabled", tint: .secondary)
                }
                Spacer(minLength: 0)
                ConnectionIndicator(state: connection)
            } meta: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(statusDetail)
                        .lineLimit(2)
                    Text(url)
                        .font(.code(.footnote))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }
            } actions: {
                if let counts {
                    HStack(spacing: 6) {
                        Pill(text: "\(counts.running) Running", tint: InstanceStatus.running.tint)
                        Pill(text: "\(counts.stopped) Stopped", tint: InstanceStatus.stopped.tint)
                        if counts.error > 0 {
                            Pill(text: "\(counts.error) Error", tint: InstanceStatus.error.tint, prominent: true)
                        }
                    }
                }
            }
            if let errorText {
                InlineMessage(text: errorText, style: .error)
            }
        }
    }
}

// MARK: - Panels

private struct HostPanel: View, Equatable {
    var info: MasterInfo
    var history: [InfoSample]
    var networkRate: Throughput?

    var body: some View {
        Panel("Host", systemImage: "cpu") {
            HStack(alignment: .top) {
                Gauge(value: info.cpuRatio) {
                    Text("CPU")
                } currentValueLabel: {
                    Text(info.cpuUsage < 0 ? "—" : "\(info.cpuUsage)%")
                }
                .gaugeStyle(RingGaugeStyle(tint: .blue, size: 58))
                Spacer()
                Gauge(value: info.memoryRatio) {
                    Text("Memory")
                } currentValueLabel: {
                    Text(Format.percent(info.memoryRatio))
                }
                .gaugeStyle(RingGaugeStyle(tint: .purple, size: 58))
                Spacer()
                Gauge(value: info.swapRatio) {
                    Text("Swap")
                } currentValueLabel: {
                    Text(info.swapTotal == 0 ? "—" : Format.percent(info.swapRatio))
                }
                .gaugeStyle(RingGaugeStyle(tint: .teal, size: 58))
                Spacer()
                let total = Double(info.networkReceived + info.networkTransmitted)
                Gauge(value: total == 0 ? 0 : Double(info.networkReceived) / total) {
                    Text("Network")
                } currentValueLabel: {
                    EmptyView()
                }
                .gaugeStyle(SplitRingGaugeStyle(
                    primaryText: "↓ \(Format.bytes(info.networkReceived, decimals: 0))",
                    secondaryText: "↑ \(Format.bytes(info.networkTransmitted, decimals: 0))",
                    primaryTint: .blue, secondaryTint: .orange, size: 58))
            }
            .padding(.horizontal, DS.Spacing.xs)

            if history.count > 2 {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("CPU · last \(history.count) samples")
                        Spacer()
                        if let networkRate {
                            RateLegend(received: networkRate.received, transmitted: networkRate.transmitted)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    Sparkline(values: history.map(\.cpu), tint: .blue, maximum: 1)
                        .frame(height: 40)
                }
            } else if let networkRate {
                PropertyRow("Throughput") {
                    RateLegend(received: networkRate.received, transmitted: networkRate.transmitted)
                }
            }
            PanelRows {
                PropertyRow("Memory", value: "\(Format.bytes(info.memoryUsed)) / \(Format.bytes(info.memoryTotal))")
                if info.swapTotal > 0 {
                    PropertyRow("Swap", value: "\(Format.bytes(info.swapUsed)) / \(Format.bytes(info.swapTotal))")
                }
                if info.diskRead > 0 || info.diskWritten > 0 {
                    PropertyRow("Disk I/O", value: "R \(Format.bytes(info.diskRead)) · W \(Format.bytes(info.diskWritten))")
                }
                if info.cpuCount > 0 {
                    PropertyRow("CPUs", value: "\(info.cpuCount)")
                }
                if info.systemUptime > 0 {
                    PropertyRow("System Uptime", value: Format.duration(seconds: info.systemUptime))
                }
            }
        }
    }
}

private struct InstancesPanel: View, Equatable {
    var counts: InstanceCounts
    var totals: TrafficTotals
    var aggregateRate: Throughput

    var body: some View {
        Panel("Instances", systemImage: "square.stack.3d.up") {
            MetricGrid {
                MetricTile(title: "Running", value: "\(counts.running)", systemImage: "play.circle.fill", tint: .green)
                MetricTile(title: "Stopped", value: "\(counts.stopped)", systemImage: "stop.circle.fill", tint: .secondary)
                MetricTile(title: "Error", value: "\(counts.error)", systemImage: "exclamationmark.triangle.fill", tint: counts.error > 0 ? .red : .secondary)
            }
            PanelRows {
                PropertyRow("Received", value: Format.bytes(totals.received))
                PropertyRow("Transmitted", value: Format.bytes(totals.transmitted))
                if aggregateRate.total > 0 {
                    PropertyRow("Throughput") {
                        RateLegend(received: aggregateRate.received, transmitted: aggregateRate.transmitted)
                    }
                }
            }
        }
    }
}

private struct IdentityPanel: View, Equatable {
    var info: MasterInfo
    var masterID: String
    var flavorName: String
    var commitAlias: (String) async -> Void

    @State private var aliasDraft = ""
    @State private var isEditingAlias = false

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.info == rhs.info && lhs.masterID == rhs.masterID && lhs.flavorName == rhs.flavorName
    }

    var body: some View {
        Panel("Master", systemImage: "info.circle") {
            PanelRows {
                PropertyRow("Alias") {
                    if isEditingAlias {
                        HStack(spacing: 6) {
                            TextField("Alias", text: $aliasDraft)
                                .textFieldStyle(.roundedBorder)
                                .multilineTextAlignment(.trailing)
                                .submitLabel(.done)
                                .onSubmit { Task { await commit() } }
                                .frame(maxWidth: 220)
                            Button("Save", systemImage: "checkmark.circle.fill") { Task { await commit() } }
                                .labelStyle(.iconOnly)
                                .buttonStyle(.borderless)
                        }
                    } else {
                        HStack(spacing: 6) {
                            Text(info.alias.isEmpty ? "—" : info.alias)
                                .font(.code(.callout))
                                .foregroundStyle(info.alias.isEmpty ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.primary))
                            Button("Edit alias", systemImage: "pencil") {
                                aliasDraft = info.alias
                                withAnimation(.signal) { isEditingAlias = true }
                            }
                            .labelStyle(.iconOnly)
                            .buttonStyle(.borderless)
                        }
                    }
                }
                CopyablePropertyRow(key: "Version", value: info.version)
                CopyablePropertyRow(key: "Hostname", value: info.hostname)
                CopyablePropertyRow(key: "Master ID", value: masterID)
                CopyablePropertyRow(key: "System", value: [info.os, info.architecture].filter { !$0.isEmpty }.joined(separator: " "))
                PropertyRow("Master Uptime", value: Format.duration(seconds: info.uptime))
                PropertyRow("Log Level", value: info.logLevel)
                PropertyRow("API TLS", value: info.tlsModeTitle)
                if !info.certificatePath.isEmpty { CopyablePropertyRow(key: "Certificate", value: info.certificatePath) }
                if !info.keyPath.isEmpty { CopyablePropertyRow(key: "Key", value: info.keyPath) }
                PropertyRow("Flavor", value: flavorName)
            }
        }
    }

    private func commit() async {
        withAnimation(.signal) { isEditingAlias = false }
        await commitAlias(aliasDraft.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

private struct AdministrationPanel: View, Equatable {
    var canRotateKey: Bool
    var showsShareAndRefresh: Bool
    var onRotateKey: () -> Void
    var onEdit: () -> Void
    var onShare: () -> Void
    var onRefresh: () -> Void

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.canRotateKey == rhs.canRotateKey && lhs.showsShareAndRefresh == rhs.showsShareAndRefresh
    }

    var body: some View {
        Panel("Administration", systemImage: "key.horizontal") {
            PanelRows {
                Button("Rotate API Key…", systemImage: "key.horizontal", action: onRotateKey)
                    .disabled(!canRotateKey)
                Button("Edit Master…", systemImage: "pencil", action: onEdit)
                if showsShareAndRefresh {
                    Button("Share…", systemImage: "qrcode", action: onShare)
                    Button("Refresh", systemImage: "arrow.clockwise", action: onRefresh)
                }
            }
            .buttonStyle(.borderless)
            .font(.subheadline)
            Text("Rotating the key regenerates it on the master and saves the new key here.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }
}

private struct NotesPanel: View, Equatable {
    var text: String

    var body: some View {
        Panel("Notes", systemImage: "note.text") {
            Text(text)
                .font(.callout)
                .textSelection(.enabled)
        }
    }
}
