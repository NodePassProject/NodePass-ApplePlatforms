//
//  MasterOverviewView.swift
//  NodePass
//
//  Health, identity and administration of a master.
//

import AppIntents
import SwiftUI

struct MasterOverviewView: View {
    @Environment(NavigationModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var session: MasterSession
    var master: Server
    var isSheet = false

    @State private var aliasDraft = ""
    @State private var isEditingAlias = false
    @State private var aliasError: String?

    var body: some View {
        Form {
            statusSection
            if let info = session.info {
                if info.hasSystemMetrics {
                    metricsSection(info)
                }
                identitySection(info)
            } else if let error = session.infoError {
                Section {
                    InlineMessage(text: error.localizedDescription, style: .error)
                }
            }
            instancesSection
            administrationSection
            if let notes = master.notes, !notes.isEmpty {
                Section("Notes") {
                    Text(notes)
                        .font(.callout)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(master.displayName)
        .inlineNavigationTitle()
        .appEntityIdentifier(EntityIdentifier(for: MasterEntity.self, identifier: master.id))
        #if os(iOS)
        .toolbar {
            if isSheet {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", role: .confirm) { dismiss() }
                }
            }
            ToolbarItem(placement: .secondaryAction) {
                Menu("More", systemImage: "ellipsis.circle") {
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

    // MARK: Sections

    private var statusSection: some View {
        Section {
            HStack(spacing: 14) {
                Image(systemName: session.connection.symbolName)
                    .font(.title2)
                    .foregroundStyle(session.connection.tint)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.connection.title)
                        .font(.headline)
                    Text(statusDetail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if !master.isEnabled {
                    Pill(text: "Disabled", tint: .secondary)
                }
            }
            if let error = session.lastError, !session.connection.isReachable {
                InlineMessage(text: error.localizedDescription, style: .error)
            }
            LabeledContent("API") {
                Text(master.url)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.trailing)
                    .textSelection(.enabled)
            }
            LabeledContent("Flavor", value: session.flavor.controllerName)
        }
    }

    private var statusDetail: String {
        switch session.connection {
        case .live:
            if let date = session.lastEventDate { return "Live events · last \(Format.relative(date))" }
            return "Receiving live events"
        case .polling:
            if let error = session.lastError {
                return "Polling every \(Int(session.instancePollInterval)) s · stream: \(error.shortDescription)"
            }
            return "Polling every \(Int(session.instancePollInterval)) s"
        case .connecting:
            return "Opening event stream…"
        case .offline(let reason):
            return reason
        case .idle:
            return master.isEnabled ? "Paused" : "Enable the master to connect"
        }
    }

    @ViewBuilder
    private func metricsSection(_ info: MasterInfo) -> some View {
        Section("Host") {
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
            .padding(.vertical, 4)

            if let rate = session.networkRate {
                LabeledContent("Throughput") {
                    RateLegend(received: rate.received, transmitted: rate.transmitted)
                }
            }
            if session.infoHistory.count > 2 {
                VStack(alignment: .leading, spacing: 4) {
                    Text("CPU · last \(session.infoHistory.count) samples")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Sparkline(values: session.infoHistory.map(\.cpu), tint: .blue, maximum: 1)
                        .frame(height: 36)
                }
            }
            KeyValueRow(key: "Memory", value: "\(Format.bytes(info.memoryUsed)) / \(Format.bytes(info.memoryTotal))")
            if info.swapTotal > 0 {
                KeyValueRow(key: "Swap", value: "\(Format.bytes(info.swapUsed)) / \(Format.bytes(info.swapTotal))")
            }
            if info.diskRead > 0 || info.diskWritten > 0 {
                KeyValueRow(key: "Disk I/O", value: "R \(Format.bytes(info.diskRead)) · W \(Format.bytes(info.diskWritten))")
            }
        }
    }

    @ViewBuilder
    private func identitySection(_ info: MasterInfo) -> some View {
        Section("Master") {
            HStack {
                Text("Alias")
                Spacer()
                if isEditingAlias {
                    TextField("Alias", text: $aliasDraft)
                        .multilineTextAlignment(.trailing)
                        .submitLabel(.done)
                        .onSubmit { Task { await commitAlias() } }
                    Button("Save", systemImage: "checkmark.circle.fill") { Task { await commitAlias() } }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.borderless)
                } else {
                    Text(info.alias.isEmpty ? "—" : info.alias)
                        .foregroundStyle(info.alias.isEmpty ? .tertiary : .primary)
                    Button("Edit alias", systemImage: "pencil") {
                        aliasDraft = info.alias
                        isEditingAlias = true
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                }
            }
            KeyValueRow(key: "Version", value: info.version)
            KeyValueRow(key: "Hostname", value: info.hostname)
            KeyValueRow(key: "Master ID", value: session.masterID)
            KeyValueRow(key: "System", value: [info.os, info.architecture].filter { !$0.isEmpty }.joined(separator: " "))
            if info.cpuCount > 0 { KeyValueRow(key: "CPUs", value: "\(info.cpuCount)") }
            KeyValueRow(key: "Master Uptime", value: Format.duration(seconds: info.uptime))
            if info.systemUptime > 0 { KeyValueRow(key: "System Uptime", value: Format.duration(seconds: info.systemUptime)) }
            KeyValueRow(key: "Log Level", value: info.logLevel)
            KeyValueRow(key: "API TLS", value: info.tlsModeTitle)
            if !info.certificatePath.isEmpty { KeyValueRow(key: "Certificate", value: info.certificatePath) }
            if !info.keyPath.isEmpty { KeyValueRow(key: "Key", value: info.keyPath) }
        }
    }

    private var instancesSection: some View {
        Section("Instances") {
            HStack(spacing: 10) {
                MetricTile(title: "Running", value: "\(session.runningCount)", systemImage: "play.circle.fill", tint: .green)
                MetricTile(title: "Stopped", value: "\(session.stoppedCount)", systemImage: "stop.circle.fill", tint: .secondary)
                MetricTile(title: "Error", value: "\(session.errorCount)", systemImage: "exclamationmark.triangle.fill", tint: .red)
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
            .listRowBackground(Color.clear)
            KeyValueRow(key: "Received", value: Format.bytes(session.totalReceived))
            KeyValueRow(key: "Transmitted", value: Format.bytes(session.totalTransmitted))
            let rate = session.aggregateRate
            if rate.received > 0 || rate.transmitted > 0 {
                LabeledContent("Throughput") {
                    RateLegend(received: rate.received, transmitted: rate.transmitted)
                }
            }
        }
    }

    private var administrationSection: some View {
        Section {
            Button("Rotate API Key…", systemImage: "key.horizontal") { model.masterPendingKeyRotation = master }
                .disabled(!session.connection.isReachable)
            Button("Edit Master…", systemImage: "pencil") { model.masterBeingEdited = master }
            #if os(macOS)
            Button("Share…", systemImage: "qrcode") { model.masterBeingShared = master }
            Button("Refresh", systemImage: "arrow.clockwise") { refresh() }
            #endif
        } header: {
            Text("Administration")
        } footer: {
            Text("Rotating the key regenerates it on the master and saves the new key here.")
        }
    }

    // MARK: Actions

    private func refresh() {
        Task {
            await session.refreshInfo()
            await session.refreshInstances()
        }
    }

    private func commitAlias() async {
        isEditingAlias = false
        let value = aliasDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value != session.info?.alias else { return }
        do {
            try await session.updateMasterAlias(value)
            Haptics.success()
        } catch {
            aliasError = APIError.wrap(error).localizedDescription
        }
    }
}
