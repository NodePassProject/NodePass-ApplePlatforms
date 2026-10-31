//
//  Entities+Transferable.swift
//  NodePass
//
//  Plain-text forms of the entities, so Siri and Apple Intelligence can summarize or share what
//  is on screen. Credentials never appear: the master's API key is not part of its entity, and
//  the instance text shows the endpoint rather than the URL that carries the tunnel password.
//

import CoreTransferable
import Foundation
import UniformTypeIdentifiers

extension MasterEntity: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .plainText) { master in
            Data(master.summaryText.utf8)
        }
    }

    var summaryText: String {
        var lines = ["Master: \(name)", "Host: \(host)"]
        if let flavor { lines.append("Flavor: \(flavor.controllerName)") }
        lines.append("Enabled: \(isEnabled ? "yes" : "no")")
        return lines.joined(separator: "\n")
    }
}

extension InstanceEntity: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .plainText) { instance in
            Data(instance.summaryText.utf8)
        }
    }

    var summaryText: String {
        var lines = [
            "Instance: \(name)",
            "Identifier: \(identifier)",
            "Master: \(master.name)",
            "Type: \(role.title)",
            "Status: \(status.title)",
            "Endpoint: \(endpoint)",
            "Auto-restart: \(autoRestart ? "on" : "off")",
            "Connections: \(tcpConnections) TCP, \(udpConnections) UDP",
            "Traffic: \(Format.bytes(instance.totalReceived)) received, \(Format.bytes(instance.totalTransmitted)) transmitted",
        ]
        if let latency { lines.append("Latency: \(Int(latency.converted(to: .milliseconds).value)) ms") }
        if !tags.isEmpty { lines.append("Tags: \(tags.joined(separator: ", "))") }
        return lines.joined(separator: "\n")
    }
}
