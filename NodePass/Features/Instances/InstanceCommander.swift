//
//  InstanceCommander.swift
//  NodePass
//
//  Runs instance operations with confirmation, error reporting and batch summaries.
//  Shared by the list and detail screens so both behave identically.
//

import SwiftUI
import Observation

struct PendingConfirmation: Identifiable {
    let id = UUID()
    var title: String
    var message: String
    var actionTitle: String
    var isDestructive: Bool
    var perform: @MainActor () async -> Void
}

struct BatchReport: Identifiable {
    let id = UUID()
    var title: String
    var outcomes: [BatchOutcome]

    var failures: [BatchOutcome] { outcomes.filter { !$0.succeeded } }
    var successCount: Int { outcomes.count - failures.count }
}

@Observable
@MainActor
final class InstanceCommander {
    var confirmation: PendingConfirmation?
    var errorMessage: String?
    var report: BatchReport?
    var isWorking = false

    /// Runs a control action on one or more instances.
    func run(_ action: InstanceAction, on ids: [String], session: MasterSession, settings: AppSettings) {
        guard !ids.isEmpty else { return }
        let names = ids.compactMap { session.instance($0)?.displayName }
        let subject = ids.count == 1 ? (names.first ?? ids[0]) : "\(ids.count) instances"
        let needsConfirmation = settings.confirmDestructiveActions && (action.isDisruptive || ids.count > 1)
        let work: @MainActor () async -> Void = { [weak self] in
            await self?.execute(title: "\(action.title) \(subject)", ids: ids, session: session) { client, id in
                _ = try await client.perform(action, on: id)
            }
        }
        if needsConfirmation {
            confirmation = PendingConfirmation(
                title: "\(action.title) \(subject)?",
                message: message(for: action, count: ids.count),
                actionTitle: action.title,
                isDestructive: action == .stop || action == .reset,
                perform: work
            )
        } else {
            Task { await work() }
        }
    }

    func delete(_ ids: [String], session: MasterSession, settings: AppSettings, completion: (@MainActor () -> Void)? = nil) {
        guard !ids.isEmpty else { return }
        let subject = ids.count == 1 ? (session.instance(ids[0])?.displayName ?? ids[0]) : "\(ids.count) instances"
        confirmation = PendingConfirmation(
            title: "Delete \(subject)?",
            message: "The instance is stopped and removed from the master. This cannot be undone.",
            actionTitle: "Delete",
            isDestructive: true
        ) { [weak self] in
            await self?.execute(title: "Delete \(subject)", ids: ids, session: session) { client, id in
                try await client.deleteInstance(id: id)
            }
            completion?()
        }
    }

    func setRestartPolicy(_ enabled: Bool, on ids: [String], session: MasterSession) {
        guard !ids.isEmpty else { return }
        Task {
            await execute(title: "\(enabled ? "Enable" : "Disable") auto-restart", ids: ids, session: session) { client, id in
                _ = try await client.setRestartPolicy(enabled, for: id)
            }
        }
    }

    func applyTag(key: String, value: String, on ids: [String], session: MasterSession) {
        guard !ids.isEmpty, !key.isEmpty else { return }
        Task {
            await execute(title: "Tag \(ids.count) instances", ids: ids, session: session) { client, id in
                let current = try await client.instance(id: id)
                var tags = current.meta.tags
                tags[key] = value
                _ = try await client.setMeta(peer: nil, tags: tags, for: id)
            }
        }
    }

    func removeTag(key: String, on ids: [String], session: MasterSession) {
        guard !ids.isEmpty, !key.isEmpty else { return }
        Task {
            await execute(title: "Untag \(ids.count) instances", ids: ids, session: session) { client, id in
                let current = try await client.instance(id: id)
                var tags = current.meta.tags
                tags.removeValue(forKey: key)
                _ = try await client.setMeta(peer: nil, tags: tags, for: id)
            }
        }
    }

    /// Runs an arbitrary async operation and surfaces its error.
    func perform(_ work: @escaping @MainActor () async throws -> Void) {
        Task {
            isWorking = true
            defer { isWorking = false }
            do {
                try await work()
            } catch {
                errorMessage = APIError.wrap(error).localizedDescription
                Haptics.warning()
            }
        }
    }

    private func execute(title: String, ids: [String], session: MasterSession, _ operation: @escaping @Sendable (MasterClient, String) async throws -> Void) async {
        isWorking = true
        defer { isWorking = false }
        let outcomes = await session.batch(ids, operation)
        let failures = outcomes.filter { !$0.succeeded }
        if ids.count == 1 {
            if let failure = failures.first {
                errorMessage = failure.error
                Haptics.warning()
            } else {
                Haptics.success()
            }
        } else {
            report = BatchReport(title: title, outcomes: outcomes)
            if failures.isEmpty { Haptics.success() } else { Haptics.warning() }
        }
    }

    private func message(for action: InstanceAction, count: Int) -> String {
        switch action {
        case .start: return count > 1 ? "Starts every selected instance that is not running." : "Starts the instance."
        case .stop: return "Active connections through the tunnel are closed."
        case .restart: return "The process is stopped and started again; connections are interrupted briefly."
        case .reset: return "Cumulative traffic counters return to zero. Connection and status information is kept."
        }
    }
}

/// Attaches the commander's confirmation, error and report presentations to a view.
struct InstanceCommanderPresentations: ViewModifier {
    @Bindable var commander: InstanceCommander

    func body(content: Content) -> some View {
        content
            .alert(
                commander.confirmation?.title ?? "",
                isPresented: Binding(get: { commander.confirmation != nil }, set: { if !$0 { commander.confirmation = nil } }),
                presenting: commander.confirmation
            ) { confirmation in
                Button(confirmation.actionTitle, role: confirmation.isDestructive ? .destructive : nil) {
                    Task { await confirmation.perform() }
                }
                Button("Cancel", role: .cancel) {}
            } message: { confirmation in
                Text(confirmation.message)
            }
            .alert("Operation Failed", isPresented: Binding(get: { commander.errorMessage != nil }, set: { if !$0 { commander.errorMessage = nil } })) {
                Button("OK", role: .cancel) { commander.errorMessage = nil }
            } message: {
                Text(commander.errorMessage ?? "")
            }
            .sheet(item: $commander.report) { report in
                BatchReportView(report: report)
            }
    }
}

extension View {
    func instanceCommanderPresentations(_ commander: InstanceCommander) -> some View {
        modifier(InstanceCommanderPresentations(commander: commander))
    }
}

struct BatchReportView: View {
    @Environment(\.dismiss) private var dismiss
    var report: BatchReport

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 12) {
                        MetricTile(title: "Succeeded", value: "\(report.successCount)", systemImage: "checkmark.circle.fill", tint: .green)
                        MetricTile(title: "Failed", value: "\(report.failures.count)", systemImage: "xmark.octagon.fill", tint: report.failures.isEmpty ? .secondary : .red)
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                }
                if !report.failures.isEmpty {
                    Section("Failures") {
                        ForEach(report.failures) { outcome in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(outcome.instanceName).font(.body.weight(.medium))
                                Text(outcome.error ?? "").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                Section("Completed") {
                    ForEach(report.outcomes.filter(\.succeeded)) { outcome in
                        Label(outcome.instanceName, systemImage: "checkmark")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(report.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", role: .confirm) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
