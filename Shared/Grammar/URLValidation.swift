//
//  URLValidation.swift
//  NodePass
//
//  Semantic checks on an `InstanceURL` beyond what parsing guarantees.
//

import Foundation

nonisolated struct ValidationIssue: Hashable, Sendable, Identifiable {
    nonisolated enum Severity: Int, Hashable, Sendable, Comparable {
        case info
        case warning
        case error

        static func < (lhs: Severity, rhs: Severity) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    nonisolated enum Field: Hashable, Sendable {
        case role
        case credential
        case tunnel
        case target(Int)
        case carriers
        case parameter(String)
        case general
    }

    var severity: Severity
    var field: Field
    var message: String

    var id: String { "\(severity.rawValue)-\(field)-\(message)" }
}

nonisolated extension InstanceURL {
    /// All issues found, most severe first.
    func validate() -> [ValidationIssue] {
        var issues: [ValidationIssue] = []

        switch role.flavor {
        case .nodePass: validateNodePass(into: &issues)
        case .openCtrl: validateNowhere(into: &issues)
        case nil:
            issues.append(.init(severity: .warning, field: .role, message: "Unknown scheme “\(role.rawValue)”. The master may reject it."))
        }

        for key in duplicateParameterKeys {
            issues.append(.init(severity: .warning, field: .parameter(key), message: "“\(key)” appears more than once; the master keeps the first value."))
        }

        return issues.sorted { $0.severity > $1.severity }
    }

    var hasErrors: Bool { validate().contains { $0.severity == .error } }

    private func validateParameters(into issues: inout [ValidationIssue]) {
        guard let flavor = role.flavor else { return }
        for parameter in parameters {
            if let spec = ParameterCatalog.spec(key: parameter.key, role: role) {
                if let problem = spec.validate(parameter.value) {
                    issues.append(.init(severity: .error, field: .parameter(parameter.key), message: "\(spec.title): \(problem)"))
                }
            } else if let spec = ParameterCatalog.spec(key: parameter.key, flavor: flavor) {
                issues.append(.init(severity: .warning, field: .parameter(parameter.key), message: "“\(spec.title)” does not apply to \(role.title) instances and will be ignored."))
            } else {
                issues.append(.init(severity: .info, field: .parameter(parameter.key), message: "“\(parameter.key)” is not a known parameter."))
            }
        }
    }

    private func validateNodePass(into issues: inout [ValidationIssue]) {
        if !tunnel.hasValidPort {
            issues.append(.init(severity: .error, field: .tunnel, message: "Tunnel port is required (1–65535)."))
        }
        let targets = targets
        if targets.isEmpty {
            issues.append(.init(severity: .error, field: .target(0), message: "A target address is required."))
        }
        for (index, target) in targets.enumerated() where !target.hasValidPort {
            issues.append(.init(severity: .error, field: .target(index), message: "Target \(index + 1) needs a port (1–65535)."))
        }
        if targets.count > 1 {
            let mode = self[parameter: "mode"] ?? "0"
            if role == .server, mode != "2" {
                issues.append(.init(severity: .warning, field: .parameter("mode"), message: "Multiple targets require forward mode (mode=2) on a server."))
            }
            if role == .client, mode != "1" {
                issues.append(.init(severity: .warning, field: .parameter("mode"), message: "Multiple targets require single-end mode (mode=1) on a client."))
            }
        }
        if let tls = self[parameter: "tls"], tls == "2" {
            if (self[parameter: "crt"] ?? "").isEmpty || (self[parameter: "key"] ?? "").isEmpty {
                issues.append(.init(severity: .warning, field: .parameter("tls"), message: "tls=2 needs crt and key unless the master supplies them."))
            }
        }
        if let type = self[parameter: "type"], type == "1" || type == "3", (self[parameter: "tls"] ?? "0") == "0" {
            issues.append(.init(severity: .warning, field: .parameter("type"), message: "QUIC and HTTP/2 pools need TLS (tls=1 or 2)."))
        }
        if role == .client, pathSegments.count > 1 {
            issues.append(.init(severity: .warning, field: .general, message: "Only one path segment is expected."))
        }
        validateParameters(into: &issues)
    }

    private func validateNowhere(into issues: inout [ValidationIssue]) {
        let key = credential ?? ""
        if key.isEmpty {
            issues.append(.init(severity: .error, field: .credential, message: "A shared key is required (32 lowercase hex characters)."))
        } else if key.count != 32 || !key.allSatisfy({ $0.isHexDigit && !$0.isUppercase }) {
            issues.append(.init(severity: .error, field: .credential, message: "The shared key must be exactly 32 lowercase hexadecimal characters."))
        }

        let carriers = carriers
        if tunnel.port != nil, !carriers.isEmpty {
            issues.append(.init(severity: .error, field: .carriers, message: "Use either a port on the host or carrier paths, not both."))
        }
        if tunnel.port == nil, carriers.isEmpty {
            issues.append(.init(severity: .error, field: .tunnel, message: "A port or at least one carrier (/tcp:PORT, /udp:PORT) is required."))
        }
        if let port = tunnel.port, !(1...65535).contains(port) {
            issues.append(.init(severity: .error, field: .tunnel, message: "Port must be between 1 and 65535."))
        }
        for carrier in carriers where carrier.port.map({ !(1...65535).contains($0) }) ?? true {
            issues.append(.init(severity: .error, field: .carriers, message: "Carrier \(carrier.kind.rawValue) needs a port (1–65535)."))
        }
        if pathSegments.count != carriers.count {
            issues.append(.init(severity: .error, field: .carriers, message: "Path segments must be carriers such as tcp:2000 or udp:2001."))
        }

        switch role {
        case .portal:
            if tunnel.host.isEmpty {
                issues.append(.init(severity: .error, field: .tunnel, message: "Portal needs a host, or * for all interfaces."))
            }
            let tcpCount = carriers.filter(\.kind.isTCP).count
            let udpCount = carriers.count - tcpCount
            if tcpCount > 1 || udpCount > 1 {
                issues.append(.init(severity: .error, field: .carriers, message: "Declare TCP and UDP at most once each."))
            }
            if (self[parameter: "out"] ?? "direct") == "egress" {
                for dial in ["dial", "dial4", "dial6"] where hasParameter(dial) {
                    issues.append(.init(severity: .error, field: .parameter(dial), message: "\(dial) conflicts with out=egress."))
                }
            }
            if (self[parameter: "tls"] ?? "1") == "2", (self[parameter: "crt"] ?? "").isEmpty || (self[parameter: "key"] ?? "").isEmpty {
                issues.append(.init(severity: .error, field: .parameter("tls"), message: "tls=2 requires both crt and key."))
            }
        case .vector, .egress:
            if tunnel.host.isEmpty || tunnel.host == "*" {
                issues.append(.init(severity: .error, field: .tunnel, message: "\(role.title) needs a concrete Portal host."))
            }
            if carriers.count > 1 {
                issues.append(.init(severity: .error, field: .carriers, message: "\(role.title) selects exactly one carrier."))
            }
            if role == .vector, (self[parameter: "in"] ?? "").isEmpty {
                issues.append(.init(severity: .error, field: .parameter("in"), message: "Vector requires in=HOST:PORT for its SOCKS5 listener."))
            }
        default:
            break
        }
        if hasParameter("dial"), hasParameter("dial4") || hasParameter("dial6") {
            issues.append(.init(severity: .error, field: .parameter("dial"), message: "dial is mutually exclusive with dial4 and dial6."))
        }
        validateParameters(into: &issues)
    }
}
