//
//  MasterStatus.swift
//  NodePass
//
//  The answer of "Get Master Status": a health check made at one moment, so a transient entity
//  rather than something the system can look up again later.
//

import AppIntents
import Foundation

nonisolated struct MasterStatus: TransientAppEntity {
    /// One health check, as the snippet and the dialog read it.
    nonisolated struct Report: Sendable {
        var master: MasterEntity
        var isReachable: Bool
        var problem: String?
        var version: String?
        var hostname: String?
        var runningCount: Int
        var stoppedCount: Int
        var errorCount: Int
        var cpuUsage: Int?
        var memoryUsage: Int?
        var uptime: Measurement<UnitDuration>?

        init(master: MasterEntity, health: MasterHealth) {
            self.master = master
            isReachable = health.isReachable
            problem = health.failure
            runningCount = health.runningCount
            stoppedCount = health.stoppedCount
            errorCount = health.errorCount
            if let info = health.info {
                version = info.version.isEmpty ? nil : info.version
                hostname = info.hostname.isEmpty ? nil : info.hostname
                cpuUsage = info.cpuUsage >= 0 ? info.cpuUsage : nil
                memoryUsage = info.memoryTotal > 0 ? Int((info.memoryRatio * 100).rounded()) : nil
                uptime = info.uptime > 0 ? Measurement(value: Double(info.uptime), unit: .seconds) : nil
            }
        }

        var symbolName: String {
            guard isReachable else { return "bolt.horizontal.circle" }
            return errorCount > 0 ? "exclamationmark.triangle.fill" : "checkmark.circle.fill"
        }

        /// One line for lists and the snippet header.
        var summary: String {
            guard isReachable else { return problem ?? "Unreachable" }
            return "\(runningCount) running · \(stoppedCount) stopped · \(errorCount) in error"
        }

        /// What Siri says.
        var dialog: IntentDialog {
            guard isReachable else {
                return IntentDialog(full: "\(master.name) is unreachable: \(problem ?? "no answer")", supporting: "\(master.host)")
            }
            let full: LocalizedStringResource = "\(master.name) is online: \(runningCount) running, \(stoppedCount) stopped, \(errorCount) in error."
            var details: [String] = []
            if let version { details.append([master.flavor?.title, version].compactMap { $0 }.joined(separator: " ")) }
            if let hostname { details.append(hostname) }
            if let cpuUsage { details.append("CPU \(cpuUsage)%") }
            if let memoryUsage { details.append("memory \(memoryUsage)%") }
            guard !details.isEmpty else { return IntentDialog(full) }
            return IntentDialog(full: full, supporting: "\(details.joined(separator: " · "))")
        }
    }

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Master Status")

    /// `nil` only for the placeholder the framework creates through `init()`.
    let report: Report?

    init() {
        report = nil
    }

    init(_ report: Report) {
        self.report = report
    }

    @ComputedProperty(title: "Master")
    var master: MasterEntity? { report?.master }

    @ComputedProperty(title: "Reachable")
    var isReachable: Bool { report?.isReachable ?? false }

    /// Why the master did not answer, when it did not.
    @ComputedProperty(title: "Problem")
    var problem: String? { report?.problem }

    @ComputedProperty(title: "Version")
    var version: String? { report?.version }

    @ComputedProperty(title: "Hostname")
    var hostname: String? { report?.hostname }

    @ComputedProperty(title: "Running Instances")
    var runningCount: Int { report?.runningCount ?? 0 }

    @ComputedProperty(title: "Stopped Instances")
    var stoppedCount: Int { report?.stoppedCount ?? 0 }

    @ComputedProperty(title: "Instances in Error")
    var errorCount: Int { report?.errorCount ?? 0 }

    @ComputedProperty(title: "CPU Usage (%)")
    var cpuUsage: Int? { report?.cpuUsage }

    @ComputedProperty(title: "Memory Usage (%)")
    var memoryUsage: Int? { report?.memoryUsage }

    @ComputedProperty(title: "Master Uptime")
    var uptime: Measurement<UnitDuration>? { report?.uptime }

    var displayRepresentation: DisplayRepresentation {
        guard let report else { return DisplayRepresentation(title: "Master Status") }
        return DisplayRepresentation(
            title: "\(report.master.name)",
            subtitle: "\(report.summary)",
            image: .init(systemName: report.symbolName)
        )
    }
}
