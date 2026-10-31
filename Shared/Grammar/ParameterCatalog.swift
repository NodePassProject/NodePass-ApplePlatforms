//
//  ParameterCatalog.swift
//  NodePass
//
//  Knowledge about every query parameter the two grammars understand: type, default,
//  applicable roles and validation. Drives the typed key–value editor.
//

import Foundation

nonisolated struct ParameterOption: Hashable, Sendable, Identifiable {
    let value: String
    let title: String
    let detail: String?

    init(_ value: String, _ title: String, _ detail: String? = nil) {
        self.value = value
        self.title = title
        self.detail = detail
    }

    var id: String { value }
}

nonisolated enum ParameterKind: Hashable, Sendable {
    /// One of a fixed set of values.
    case options([ParameterOption])
    /// Suggested values, but any text is accepted (e.g. `out=direct|egress|host:port`).
    case suggestions([ParameterOption])
    /// Integer, optionally bounded.
    case integer(min: Int?, max: Int?)
    /// Go-style duration such as `5m`, `30s`, `1h30m`; `0` disables.
    case duration
    /// `0` or `1`.
    case boolean
    /// Digits that may be combined in any order (`block=12`).
    case bitSet([ParameterOption])
    /// Hostname or IP literal (`auto` allowed when stated in options).
    case host
    /// Filesystem path on the master host.
    case path
    /// `[user:pass@]host:port`.
    case hostPort
    /// Fixed-length lowercase hexadecimal string.
    case hex(length: Int)
    case text
}

nonisolated enum ParameterGroup: String, CaseIterable, Hashable, Sendable, Identifiable, Comparable {
    case logging
    case security
    case connection
    case network
    case protocolControl
    case traffic
    case routing
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .logging: "Logging"
        case .security: "Security"
        case .connection: "Connection"
        case .network: "Network"
        case .protocolControl: "Protocol"
        case .traffic: "Traffic"
        case .routing: "Routing"
        case .custom: "Custom"
        }
    }

    var symbolName: String {
        switch self {
        case .logging: "text.alignleft"
        case .security: "lock.shield"
        case .connection: "point.3.connected.trianglepath.dotted"
        case .network: "network"
        case .protocolControl: "switch.2"
        case .traffic: "arrow.left.arrow.right"
        case .routing: "arrow.triangle.branch"
        case .custom: "curlybraces"
        }
    }

    private var order: Int { Self.allCases.firstIndex(of: self) ?? 0 }
    static func < (lhs: ParameterGroup, rhs: ParameterGroup) -> Bool { lhs.order < rhs.order }
}

nonisolated struct ParameterSpec: Hashable, Sendable, Identifiable {
    let key: String
    let title: String
    let summary: String
    let kind: ParameterKind
    /// Value the master assumes when the parameter is absent.
    let defaultValue: String?
    let roles: Set<InstanceRole>
    let group: ParameterGroup
    let placeholder: String?
    /// Unit shown next to numeric values.
    let unit: String?

    init(key: String,
         title: String,
         summary: String,
         kind: ParameterKind,
         defaultValue: String? = nil,
         roles: Set<InstanceRole>,
         group: ParameterGroup,
         placeholder: String? = nil,
         unit: String? = nil) {
        self.key = key
        self.title = title
        self.summary = summary
        self.kind = kind
        self.defaultValue = defaultValue
        self.roles = roles
        self.group = group
        self.placeholder = placeholder
        self.unit = unit
    }

    var id: String { key + ":" + roles.map(\.rawValue).sorted().joined(separator: ",") }

    func applies(to role: InstanceRole) -> Bool { roles.contains(role) }

    /// Options for enumerated kinds, otherwise empty.
    var options: [ParameterOption] {
        switch kind {
        case .options(let options), .suggestions(let options), .bitSet(let options): options
        default: []
        }
    }

    /// Returns a problem description, or nil when `value` is acceptable.
    func validate(_ rawValue: String) -> String? {
        let value = rawValue.trimmingCharacters(in: .whitespaces)
        switch kind {
        case .options(let options):
            return options.contains { $0.value == value } ? nil : "Expected one of \(options.map(\.value).joined(separator: ", "))."
        case .suggestions:
            return value.isEmpty ? "Value required." : nil
        case .integer(let min, let max):
            guard let number = Int(value) else { return "Expected a whole number." }
            if let min, number < min { return "Must be at least \(min)." }
            if let max, number > max { return "Must be at most \(max)." }
            return nil
        case .duration:
            return Self.isValidDuration(value) ? nil : "Expected a duration such as 30s, 5m or 1h."
        case .boolean:
            return value == "0" || value == "1" ? nil : "Expected 0 or 1."
        case .bitSet(let options):
            if value == "0" || value.isEmpty { return nil }
            let allowed = Set(options.map(\.value))
            return value.allSatisfy { allowed.contains(String($0)) } ? nil : "Use digits \(options.map(\.value).joined(separator: ", ")) in any combination."
        case .host:
            return value.isEmpty ? "Host required." : nil
        case .path:
            return value.isEmpty ? "Path required." : nil
        case .hostPort:
            let endpoint = HostPort(parsing: value.split(separator: "@").last.map(String.init) ?? value)
            return endpoint.hasValidPort ? nil : "Expected host:port."
        case .hex(let length):
            let isHex = value.count == length && value.allSatisfy { $0.isHexDigit && !$0.isUppercase }
            return isHex || value.isEmpty || value == "none" ? nil : "Expected \(length) lowercase hexadecimal characters."
        case .text:
            return nil
        }
    }

    /// Friendly rendering of a raw value (option titles, units).
    func displayValue(_ rawValue: String) -> String {
        switch kind {
        case .options(let options), .suggestions(let options):
            return options.first { $0.value == rawValue }?.title ?? rawValue
        case .bitSet(let options):
            if rawValue == "0" || rawValue.isEmpty { return "None" }
            let titles = options.filter { rawValue.contains($0.value) }.map(\.title)
            return titles.isEmpty ? rawValue : titles.joined(separator: ", ")
        case .boolean:
            return rawValue == "1" ? "On" : "Off"
        case .integer:
            if let unit, !rawValue.isEmpty { return "\(rawValue) \(unit)" }
            return rawValue
        default:
            return rawValue
        }
    }

    static func isValidDuration(_ value: String) -> Bool {
        if value == "0" { return true }
        var index = value.startIndex
        var sawComponent = false
        while index < value.endIndex {
            var digits = ""
            while index < value.endIndex, value[index].isNumber || value[index] == "." {
                digits.append(value[index])
                index = value.index(after: index)
            }
            guard !digits.isEmpty, Double(digits) != nil else { return false }
            var unit = ""
            while index < value.endIndex, !value[index].isNumber {
                unit.append(value[index])
                index = value.index(after: index)
            }
            guard ["ns", "us", "µs", "ms", "s", "m", "h"].contains(unit) else { return false }
            sawComponent = true
        }
        return sawComponent
    }
}

nonisolated enum ParameterCatalog {
    static func specs(for flavor: MasterFlavor) -> [ParameterSpec] {
        switch flavor {
        case .nodePass: nodePass
        case .openCtrl: nowhere
        }
    }

    /// Specs applicable to one role, grouped and ordered for presentation.
    static func specs(for role: InstanceRole) -> [ParameterSpec] {
        guard let flavor = role.flavor else { return [] }
        return specs(for: flavor).filter { $0.applies(to: role) }
    }

    static func spec(key: String, role: InstanceRole) -> ParameterSpec? {
        specs(for: role).first { $0.key == key }
    }

    static func spec(key: String, flavor: MasterFlavor) -> ParameterSpec? {
        specs(for: flavor).first { $0.key == key }
    }

    // MARK: NodePass

    static let logLevelOptions: [ParameterOption] = [
        .init("none", "None", "Disable logging"),
        .init("debug", "Debug", "Everything, including every connection"),
        .init("info", "Info", "Startup, shutdown and key events"),
        .init("warn", "Warn", "Potential issues only"),
        .init("error", "Error", "Failures only"),
        .init("event", "Event", "Operational events and traffic statistics"),
    ]

    static let tlsOptions: [ParameterOption] = [
        .init("0", "No TLS", "Plain data channel"),
        .init("1", "Self-signed", "Auto-generated certificate"),
        .init("2", "Custom certificate", "Requires crt and key"),
    ]

    static let nodePass: [ParameterSpec] = {
        let both: Set<InstanceRole> = [.server, .client]
        let server: Set<InstanceRole> = [.server]
        let client: Set<InstanceRole> = [.client]
        return [
            ParameterSpec(key: "log", title: "Log level", summary: "Verbosity of the instance log.", kind: .options(logLevelOptions), defaultValue: "info", roles: both, group: .logging),
            ParameterSpec(key: "tls", title: "TLS mode", summary: "Encryption of the data channel. Delivered to clients during the handshake.", kind: .options(tlsOptions), defaultValue: "0", roles: server, group: .security),
            ParameterSpec(key: "crt", title: "Certificate path", summary: "PEM certificate on the master host, used when tls=2.", kind: .path, roles: server, group: .security, placeholder: "/etc/nodepass/cert.pem"),
            ParameterSpec(key: "key", title: "Private key path", summary: "PEM private key on the master host, used when tls=2.", kind: .path, roles: server, group: .security, placeholder: "/etc/nodepass/key.pem"),
            ParameterSpec(key: "sni", title: "SNI hostname", summary: "Server name sent in the TLS handshake (dual-end mode).", kind: .host, defaultValue: "none", roles: client, group: .security, placeholder: "example.com"),
            ParameterSpec(key: "mode", title: "Run mode", summary: "Direction of the data flow. Auto tries local binding first.", kind: .options([
                .init("0", "Auto", "Detect by binding attempt"),
                .init("1", "Reverse", "Server binds the target and receives traffic"),
                .init("2", "Forward", "Server dials the remote target"),
            ]), defaultValue: "0", roles: server, group: .connection),
            ParameterSpec(key: "mode", title: "Run mode", summary: "Single-end forwards locally with a pool; dual-end handshakes with a server.", kind: .options([
                .init("0", "Auto", "Detect by binding attempt"),
                .init("1", "Single-end", "Local proxy with connection pooling"),
                .init("2", "Dual-end", "Handshake with the server"),
            ]), defaultValue: "0", roles: client, group: .connection),
            ParameterSpec(key: "type", title: "Pool type", summary: "Transport of the connection pool. Clients receive it during the handshake.", kind: .options([
                .init("0", "TCP"),
                .init("1", "QUIC", "Requires tls ≥ 1"),
                .init("2", "WebSocket"),
                .init("3", "HTTP/2", "Requires tls ≥ 1"),
            ]), defaultValue: "0", roles: server, group: .connection),
            ParameterSpec(key: "min", title: "Minimum pool", summary: "Connections the client keeps ready.", kind: .integer(min: 1, max: nil), defaultValue: "64", roles: client, group: .connection, unit: "connections"),
            ParameterSpec(key: "max", title: "Maximum pool", summary: "Upper bound of the pool, enforced by the server.", kind: .integer(min: 1, max: nil), defaultValue: "1024", roles: server, group: .connection, unit: "connections"),
            ParameterSpec(key: "dns", title: "DNS cache TTL", summary: "How long resolved target addresses are cached.", kind: .duration, defaultValue: "5m", roles: both, group: .network, placeholder: "5m"),
            ParameterSpec(key: "dial", title: "Dial source IP", summary: "Source address for outbound connections, or auto.", kind: .host, defaultValue: "auto", roles: both, group: .network, placeholder: "auto"),
            ParameterSpec(key: "read", title: "Read timeout", summary: "Idle read deadline for data connections; 0 disables it.", kind: .duration, defaultValue: "0", roles: both, group: .network, placeholder: "30s"),
            ParameterSpec(key: "rate", title: "Rate limit", summary: "Bandwidth cap in megabits per second; 0 is unlimited.", kind: .integer(min: 0, max: nil), defaultValue: "0", roles: both, group: .network, unit: "Mbps"),
            ParameterSpec(key: "slot", title: "Connection slots", summary: "Maximum concurrent connections; 0 is unlimited.", kind: .integer(min: 0, max: nil), defaultValue: "65536", roles: both, group: .network),
            ParameterSpec(key: "proxy", title: "PROXY protocol", summary: "Send a PROXY protocol v1 header before data.", kind: .boolean, defaultValue: "0", roles: both, group: .protocolControl),
            ParameterSpec(key: "notcp", title: "Disable TCP", summary: "Skip TCP forwarding entirely.", kind: .boolean, defaultValue: "0", roles: both, group: .protocolControl),
            ParameterSpec(key: "noudp", title: "Disable UDP", summary: "Skip UDP forwarding entirely.", kind: .boolean, defaultValue: "0", roles: both, group: .protocolControl),
            ParameterSpec(key: "block", title: "Protocol blocking", summary: "Reject connections whose first bytes match these protocols.", kind: .bitSet([
                .init("1", "SOCKS", "SOCKS4/4a/5"),
                .init("2", "HTTP", "All HTTP methods"),
                .init("3", "TLS", "TLS handshakes"),
            ]), defaultValue: "0", roles: both, group: .traffic),
            ParameterSpec(key: "lbs", title: "Load balancing", summary: "Target selection strategy when several targets are listed.", kind: .options([
                .init("0", "Round-robin", "Rotate targets, fail over on error"),
                .init("1", "Optimal latency", "Prefer the fastest probed target"),
                .init("2", "Primary-backup", "Use the first target, fall back in order"),
            ]), defaultValue: "0", roles: both, group: .traffic),
        ]
    }()

    // MARK: Nowhere

    static let nowhere: [ParameterSpec] = {
        let all: Set<InstanceRole> = [.portal, .vector, .egress]
        let portal: Set<InstanceRole> = [.portal]
        let vector: Set<InstanceRole> = [.vector]
        let clients: Set<InstanceRole> = [.vector, .egress]
        let dialers: Set<InstanceRole> = [.portal, .egress]
        return [
            ParameterSpec(key: "in", title: "SOCKS5 ingress", summary: "Local listener applications connect to. Optional user:pass@ prefix.", kind: .hostPort, roles: vector, group: .routing, placeholder: "127.0.0.1:1080"),
            ParameterSpec(key: "out", title: "Exit", summary: "direct, egress or an upstream SOCKS5 proxy.", kind: .suggestions([
                .init("direct", "Direct", "Dial targets from the Portal host"),
                .init("egress", "Egress", "Use registered remote exits"),
            ]), defaultValue: "direct", roles: portal, group: .routing, placeholder: "direct"),
            ParameterSpec(key: "tls", title: "TLS mode", summary: "Generated (1) or supplied (2) certificate for TLS and QUIC.", kind: .options([
                .init("1", "Generated certificate"),
                .init("2", "Supplied PEM files", "Requires crt and key"),
            ]), defaultValue: "1", roles: portal, group: .security),
            ParameterSpec(key: "crt", title: "Certificate path", summary: "Certificate chain PEM, required with tls=2.", kind: .path, roles: portal, group: .security, placeholder: "/etc/nowhere/cert.pem"),
            ParameterSpec(key: "key", title: "Private key path", summary: "Private key PEM, required with tls=2.", kind: .path, roles: portal, group: .security, placeholder: "/etc/nowhere/key.pem"),
            ParameterSpec(key: "sni", title: "Server name", summary: "Verified server name; empty or none uses the host.", kind: .host, roles: clients, group: .security, placeholder: "portal.example"),
            ParameterSpec(key: "pin", title: "Certificate pin", summary: "Exact SHA-256 of the Portal certificate; empty uses CA verification.", kind: .hex(length: 64), roles: clients, group: .security),
            ParameterSpec(key: "morph", title: "Morph masking", summary: "Shared-key masking of the wire image. Peers must agree.", kind: .boolean, defaultValue: "1", roles: all, group: .security),
            ParameterSpec(key: "dial", title: "Dial source", summary: "Outbound source IP or auto. Conflicts with out=egress.", kind: .host, defaultValue: "auto", roles: dialers, group: .network, placeholder: "auto"),
            ParameterSpec(key: "dial4", title: "Dial source (IPv4)", summary: "IPv4 outbound source binding.", kind: .host, defaultValue: "auto", roles: dialers, group: .network, placeholder: "auto"),
            ParameterSpec(key: "dial6", title: "Dial source (IPv6)", summary: "IPv6 outbound source binding.", kind: .host, defaultValue: "auto", roles: dialers, group: .network, placeholder: "auto"),
            ParameterSpec(key: "rate", title: "Upload limit", summary: "Vector → Target limit in Mbps; 0 disables it.", kind: .integer(min: 0, max: 2_147_483_647), defaultValue: "0", roles: all, group: .traffic, unit: "Mbps"),
            ParameterSpec(key: "etar", title: "Download limit", summary: "Target → Vector limit in Mbps; 0 disables it.", kind: .integer(min: 0, max: 2_147_483_647), defaultValue: "0", roles: all, group: .traffic, unit: "Mbps"),
        ]
    }()
}
