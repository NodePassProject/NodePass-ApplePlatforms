//
//  Endpoint.swift
//  NodePass
//
//  `host:port` pairs as they appear in instance URLs. Hosts may be empty (all interfaces),
//  `*` (Nowhere wildcard) or bracketed IPv6 literals.
//

import Foundation

nonisolated struct HostPort: Hashable, Sendable, CustomStringConvertible {
    var host: String
    var port: Int?

    init(host: String = "", port: Int? = nil) {
        self.host = host
        self.port = port
    }

    /// Parses `host`, `host:port`, `:port`, `[v6]:port` or `[v6]`. Never fails; an unparsable port is kept as `nil`.
    init(parsing text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("[") {
            if let close = trimmed.firstIndex(of: "]") {
                host = String(trimmed[trimmed.index(after: trimmed.startIndex)..<close])
                let rest = trimmed[trimmed.index(after: close)...]
                port = rest.hasPrefix(":") ? Int(rest.dropFirst()) : nil
            } else {
                host = trimmed
                port = nil
            }
            return
        }
        let colons = trimmed.filter { $0 == ":" }.count
        if colons > 1 {
            // Unbracketed IPv6 literal without port.
            host = trimmed
            port = nil
            return
        }
        if let colon = trimmed.lastIndex(of: ":") {
            host = String(trimmed[..<colon])
            port = Int(trimmed[trimmed.index(after: colon)...])
        } else {
            host = trimmed
            port = nil
        }
    }

    /// Serialized form, bracketing IPv6 hosts.
    var description: String {
        let renderedHost = host.contains(":") && !host.hasPrefix("[") ? "[\(host)]" : host
        if let port { return "\(renderedHost):\(port)" }
        return renderedHost
    }

    var isWildcard: Bool {
        host.isEmpty || host == "*" || host == "0.0.0.0" || host == "::" || host == "[::]"
    }

    var isLoopback: Bool {
        host == "127.0.0.1" || host == "localhost" || host == "::1"
    }

    var hasValidPort: Bool {
        guard let port else { return false }
        return (1...65535).contains(port)
    }

    /// Human-friendly host label.
    var displayHost: String {
        if host.isEmpty { return "0.0.0.0" }
        return host
    }
}

/// Nowhere listener / connection carriers declared in the URL path (`/tcp:2000/udp6:2001`).
nonisolated struct Carrier: Hashable, Sendable, CustomStringConvertible, Identifiable {
    nonisolated enum Kind: String, CaseIterable, Hashable, Sendable {
        case tcp, tcp4, tcp6, udp, udp4, udp6

        var transport: String { hasPrefix("tcp") ? "TLS" : "QUIC" }
        var family: String {
            switch self {
            case .tcp, .udp: "IPv4 / IPv6"
            case .tcp4, .udp4: "IPv4"
            case .tcp6, .udp6: "IPv6"
            }
        }
        var isTCP: Bool { hasPrefix("tcp") }
        private func hasPrefix(_ prefix: String) -> Bool { rawValue.hasPrefix(prefix) }
    }

    var kind: Kind
    var port: Int?

    var id: String { description }

    init(kind: Kind, port: Int?) {
        self.kind = kind
        self.port = port
    }

    /// Parses `tcp:2000`; returns nil for segments that are not carriers.
    init?(parsing segment: String) {
        guard let colon = segment.firstIndex(of: ":"),
              let kind = Kind(rawValue: String(segment[..<colon]).lowercased()) else { return nil }
        self.kind = kind
        self.port = Int(segment[segment.index(after: colon)...])
    }

    var description: String {
        if let port { return "\(kind.rawValue):\(port)" }
        return kind.rawValue
    }
}
