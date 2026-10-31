//
//  MasterDetailView.swift
//  NodePass Watch App
//
//  One master: connection, host load and its instances.
//

import AppIntents
import SwiftUI

struct MasterDetailView: View {
    @Environment(SessionStore.self) private var sessions
    @Environment(MasterMirror.self) private var mirror
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    var masterID: String

    var body: some View {
        if let master = mirror.snapshot(id: masterID) {
            if let session = sessions.session(for: masterID) {
                content(master, session)
            } else {
                // The session appears a moment after the master arrives.
                ProgressView()
                    .navigationTitle(master.name)
            }
        } else {
            ContentUnavailableView("Master Removed", systemImage: "server.rack", description: Text("This master is no longer saved on your iPhone."))
        }
    }

    private func content(_ master: MasterSnapshot, _ session: MasterSession) -> some View {
        List {
            statusSection(master, session)
            if let info = session.info, info.hasSystemMetrics {
                hostSection(info, session)
            }
            instancesSection(session)
        }
        .navigationTitle(master.name)
        .containerBackground(session.health.tint.opacity(0.7).gradient, for: .navigation)
        .appEntityIdentifier(EntityIdentifier(for: MasterEntity.self, identifier: master.id))
    }

    // MARK: Sections

    private func statusSection(_ master: MasterSnapshot, _ session: MasterSession) -> some View {
        Section {
            HStack(spacing: 10) {
                HealthGlyph(health: session.health)
                    .font(.title2)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.health.title)
                        .font(.headline)
                    Text(statusDetail(session))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            }
            .padding(.vertical, 2)
        } footer: {
            Text(master.host ?? master.url)
                .font(.caption2.monospaced())
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    /// The connection's state; when the master is offline, what went wrong in full.
    private func statusDetail(_ session: MasterSession) -> String {
        if case .offline = session.connection, let error = session.lastError {
            return error.localizedDescription
        }
        return session.connectionDetail
    }

    private func hostSection(_ info: MasterInfo, _ session: MasterSession) -> some View {
        Section("Host") {
            HStack(alignment: .top) {
                Spacer(minLength: 0)
                Gauge(value: info.cpuRatio) {
                    Text("CPU")
                } currentValueLabel: {
                    Text(info.cpuUsage < 0 ? "—" : "\(info.cpuUsage)%")
                }
                .gaugeStyle(RingGaugeStyle(tint: .blue, size: 54))
                Spacer(minLength: 12)
                Gauge(value: info.memoryRatio) {
                    Text("Memory")
                } currentValueLabel: {
                    Text(Format.percent(info.memoryRatio))
                }
                .gaugeStyle(RingGaugeStyle(tint: .purple, size: 54))
                Spacer(minLength: 0)
            }
            .padding(.vertical, 4)
            if !isLuminanceReduced, let rate = session.networkRate {
                RateLegend(received: rate.received, transmitted: rate.transmitted)
            }
            if info.uptime > 0 {
                LabeledContent("Uptime", value: Format.duration(seconds: info.uptime, compact: true))
            }
            if !info.version.isEmpty {
                LabeledContent("Version", value: info.version)
            }
        }
    }

    private func instancesSection(_ session: MasterSession) -> some View {
        Section {
            let instances = sortedInstances(session)
            if instances.isEmpty {
                Text(emptyInstancesText(session))
                    .foregroundStyle(.secondary)
            }
            ForEach(instances) { instance in
                NavigationLink(value: WatchRoute.instance(masterID: session.id, instanceID: instance.id)) {
                    InstanceRow(instance: instance, isBusy: session.isBusy(instance.id), rate: session.rateTracker(for: instance.id).latest)
                }
            }
        } header: {
            HStack {
                Text("Instances")
                Spacer()
                if session.hasLoadedInstances {
                    Text("\(session.runningCount)/\(session.visibleInstances.count)")
                        .monospacedDigit()
                }
            }
        }
    }

    private func emptyInstancesText(_ session: MasterSession) -> String {
        if session.hasLoadedInstances { return "No instances" }
        if case .offline = session.connection { return "Unavailable while offline" }
        return "Loading…"
    }

    /// Errors first, then running instances, then the rest, each group by name.
    private func sortedInstances(_ session: MasterSession) -> [Instance] {
        session.visibleInstances.sorted { lhs, rhs in
            if lhs.status != rhs.status { return lhs.status < rhs.status }
            return lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
        }
    }
}

/// One instance of the master: state, name and what it is doing right now.
struct InstanceRow: View {
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    var instance: Instance
    var isBusy: Bool
    var rate: RateSample?

    var body: some View {
        HStack(spacing: 8) {
            StatusDot(status: instance.status, size: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(instance.displayName)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                Text(detail)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            if isBusy {
                ProgressView()
                    .controlSize(.mini)
            } else if instance.restart {
                Image(systemName: "arrow.trianglehead.clockwise")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .accessibilityLabel("Auto-restart on")
            }
        }
    }

    private var detail: String {
        var parts = [instance.role.title]
        if !isLuminanceReduced, let rate, rate.received + rate.transmitted > 0 {
            parts.append(Format.bitRate(bytesPerSecond: rate.received + rate.transmitted))
        } else {
            parts.append("↓\(Format.bytes(instance.totalReceived, decimals: 0)) ↑\(Format.bytes(instance.totalTransmitted, decimals: 0))")
        }
        return parts.joined(separator: " · ")
    }
}
