//
//  TCPingResultEntity.swift
//  NodePass
//
//  The answer of "TCP Ping": one measurement, so a transient entity.
//

import AppIntents
import Foundation

nonisolated struct TCPingResultEntity: TransientAppEntity {
    nonisolated struct Outcome: Sendable {
        var target: String
        var master: MasterEntity
        var isConnected: Bool
        var latency: Measurement<UnitDuration>?
        var error: String?

        init(_ result: TCPingResult, target: String, master: MasterEntity) {
            self.target = result.target.isEmpty ? target : result.target
            self.master = master
            isConnected = result.connected
            latency = result.connected ? Measurement(value: Double(result.latency), unit: .milliseconds) : nil
            error = result.error?.isEmpty == false ? result.error : nil
        }

        var latencyText: String {
            guard let latency else { return "—" }
            return "\(Int(latency.converted(to: .milliseconds).value)) ms"
        }

        var summary: String {
            isConnected ? "\(latencyText) from \(master.name)" : (error ?? "No answer")
        }

        var dialog: IntentDialog {
            if isConnected {
                return IntentDialog("\(target) answered from \(master.name) in \(latencyText).")
            }
            return IntentDialog("\(target) did not answer from \(master.name): \(error ?? "no response").")
        }
    }

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "TCP Ping Result")

    /// `nil` only for the placeholder the framework creates through `init()`.
    let outcome: Outcome?

    init() {
        outcome = nil
    }

    init(_ outcome: Outcome) {
        self.outcome = outcome
    }

    @ComputedProperty(title: "Target")
    var target: String { outcome?.target ?? "" }

    @ComputedProperty(title: "Master")
    var master: MasterEntity? { outcome?.master }

    @ComputedProperty(title: "Connected")
    var isConnected: Bool { outcome?.isConnected ?? false }

    @ComputedProperty(title: "Latency")
    var latency: Measurement<UnitDuration>? { outcome?.latency }

    @ComputedProperty(title: "Error")
    var error: String? { outcome?.error }

    var displayRepresentation: DisplayRepresentation {
        guard let outcome else { return DisplayRepresentation(title: "TCP Ping Result") }
        return DisplayRepresentation(
            title: "\(outcome.target)",
            subtitle: "\(outcome.summary)",
            image: .init(systemName: outcome.isConnected ? "checkmark.circle.fill" : "xmark.octagon.fill")
        )
    }
}
