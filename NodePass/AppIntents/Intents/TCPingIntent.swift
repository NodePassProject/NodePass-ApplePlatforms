//
//  TCPingIntent.swift
//  NodePass
//
//  The TCP Ping tool as an action: a master dials a host:port and reports the latency.
//

import AppIntents

struct TCPingIntent: nonisolated AppIntent {
    nonisolated static let title: LocalizedStringResource = "TCP Ping"
    nonisolated static let description = IntentDescription(
        "Asks a master to open a TCP connection to a host and port and reports whether it answered and how fast.",
        categoryName: "Tools",
        resultValueName: "TCP Ping Result"
    )

    nonisolated static var parameterSummary: some ParameterSummary {
        Summary("Ping \(\.$target) from \(\.$master)")
    }

    @Parameter(title: "Target", requestValueDialog: "Which host and port?")
    var target: String

    @Parameter(title: "Master", requestValueDialog: "From which master?")
    var master: MasterEntity

    @Dependency private var model: IntentModel

    nonisolated init() {}

    init(target: String, master: MasterEntity) {
        self.target = target
        self.master = master
    }

    @MainActor
    func perform() async throws -> some ReturnsValue<TCPingResultEntity> & ProvidesDialog {
        let snapshot = try model.master(for: master)
        guard let target = Self.normalizedTarget(target) else {
            throw $target.needsValueError("Enter a host and port, such as example.com:443.")
        }
        let outcome = TCPingResultEntity.Outcome(try await model.tcping(target, from: snapshot), target: target, master: MasterEntity(snapshot))
        return .result(value: TCPingResultEntity(outcome), dialog: outcome.dialog)
    }

    /// The target as the master should see it, or `nil` when it has no usable port.
    nonisolated static func normalizedTarget(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return HostPort(parsing: trimmed).hasValidPort ? trimmed : nil
    }
}
