//
//  InstanceDetailView.swift
//  NodePass Watch App
//
//  One instance: its state and traffic, the auto-restart policy, and Start, Stop and Restart in
//  the bottom bar. Stopping and restarting interrupt connections, so they ask first.
//

import AppIntents
import SwiftUI

struct InstanceDetailView: View {
    @Environment(SessionStore.self) private var sessions
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    var masterID: String
    var instanceID: String

    @State private var pendingAction: InstanceAction?
    @State private var restartDraft: Bool?
    @State private var errorMessage: String?

    var body: some View {
        if let session = sessions.session(for: masterID), let instance = session.instance(instanceID) {
            content(instance, session)
        } else {
            ContentUnavailableView("Instance Removed", systemImage: "trash", description: Text("This instance no longer exists on the master."))
        }
    }

    private func content(_ instance: Instance, _ session: MasterSession) -> some View {
        List {
            headerSection(instance, session)
            trafficSection(instance, session)
            policySection(instance, session)
            detailsSection(instance, session)
        }
        .navigationTitle(instance.displayName)
        .containerBackground(instance.role.tint.opacity(0.7).gradient, for: .navigation)
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                if instance.status == .running {
                    Button("Stop", systemImage: "stop.fill") { pendingAction = .stop }
                        .tint(.orange)
                } else {
                    Button("Start", systemImage: "play.fill") { run(.start, on: instance, session) }
                        .tint(.green)
                }
                Spacer()
                Button("Restart", systemImage: "arrow.clockwise") { pendingAction = .restart }
                    .tint(.blue)
            }
        }
        .disabled(session.isBusy(instance.id))
        .confirmationDialog(
            pendingAction.map { "\($0.title) \(instance.displayName)?" } ?? "",
            isPresented: Binding(isPresenting: $pendingAction),
            titleVisibility: .visible,
            presenting: pendingAction
        ) { action in
            Button(action.title, role: action == .stop ? .destructive : nil) { run(action, on: instance, session) }
            Button("Cancel", role: .cancel) {}
        } message: { action in
            Text(action == .stop ? "Connections through it are closed." : "Connections are interrupted briefly.")
        }
        .alert("Operation Failed", isPresented: Binding(isPresenting: $errorMessage)) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        // Tells Siri which instance is on screen.
        .appEntityIdentifier(EntityIdentifier(for: InstanceEntity.self, identifier: InstanceEntity.ID(masterID: masterID, instanceID: instance.id)))
    }

    // MARK: Sections

    private func headerSection(_ instance: Instance, _ session: MasterSession) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    StatusPill(status: instance.status, prominent: true)
                    RolePill(role: instance.role)
                    Spacer(minLength: 0)
                    if session.isBusy(instance.id) {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
                Text(instance.endpointSummary)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.middle)
            }
            .padding(.vertical, 2)
        }
    }

    private func trafficSection(_ instance: Instance, _ session: MasterSession) -> some View {
        Section("Traffic") {
            let tracker = session.rateTracker(for: instance.id)
            if !isLuminanceReduced, tracker.samples.count > 1, tracker.peak > 0 {
                VStack(alignment: .leading, spacing: 4) {
                    TrafficSparkline(samples: tracker.samples, height: 32)
                    if let latest = tracker.latest {
                        RateLegend(received: latest.received, transmitted: latest.transmitted)
                    }
                }
                .padding(.vertical, 2)
            }
            LabeledContent("Received", value: Format.bytes(instance.totalReceived, decimals: 1))
            LabeledContent("Sent", value: Format.bytes(instance.totalTransmitted, decimals: 1))
            LabeledContent("TCP", value: "\(instance.tcpConnections)")
            LabeledContent("UDP", value: "\(instance.udpConnections)")
            if instance.ping > 0 {
                LabeledContent("Latency", value: Format.latency(milliseconds: instance.ping))
            }
            if instance.pool > 0 {
                LabeledContent("Pool", value: "\(instance.pool)")
            }
        }
        .monospacedDigit()
    }

    private func policySection(_ instance: Instance, _ session: MasterSession) -> some View {
        Section {
            Toggle("Auto-restart", isOn: Binding(
                get: { restartDraft ?? instance.restart },
                set: { enabled in setRestartPolicy(enabled, on: instance, session) }
            ))
        } footer: {
            Text("The master restarts the instance whenever it exits.")
        }
    }

    private func detailsSection(_ instance: Instance, _ session: MasterSession) -> some View {
        Section("Details") {
            LabeledContent("Master", value: session.displayName)
            LabeledContent("ID", value: instance.id)
            ForEach(instance.meta.sortedTags, id: \.key) { tag in
                LabeledContent(tag.key, value: tag.value.isEmpty ? "—" : tag.value)
            }
        }
    }

    // MARK: Actions

    private func run(_ action: InstanceAction, on instance: Instance, _ session: MasterSession) {
        Task {
            do {
                try await session.perform(action, on: instance.id)
                Haptics.success()
            } catch {
                errorMessage = APIError.wrap(error).localizedDescription
                Haptics.failure()
            }
        }
    }

    private func setRestartPolicy(_ enabled: Bool, on instance: Instance, _ session: MasterSession) {
        restartDraft = enabled
        Task {
            defer { restartDraft = nil }
            do {
                try await session.patch(InstancePatch(restart: enabled), for: instance.id)
                Haptics.click()
            } catch {
                errorMessage = APIError.wrap(error).localizedDescription
                Haptics.failure()
            }
        }
    }
}
