//
//  InstanceURL.swift
//  NodePass
//
//  Structured representation of an instance URL for both grammars:
//
//    NodePass:  server://[password@]host:port/target[,target…]?k=v&…
//    Nowhere:   portal://KEY@host[:port][/tcp:port][/udp:port]?k=v&…
//
//  Parsing is tolerant (wildcard `*` hosts, empty hosts, IPv6) and keeps query parameters in
//  order so that an editor can round-trip without reshuffling the user's text.
//

import Foundation

nonisolated struct URLParameter: Hashable, Sendable {
    var key: String
    var value: String

    init(_ key: String, _ value: String) {
        self.key = key
        self.value = value
    }
}

nonisolated enum InstanceURLError: Error, LocalizedError, Hashable, Sendable {
    case empty
    case missingScheme
    case missingAuthority

    var errorDescription: String? {
        switch self {
        case .empty: "The URL is empty."
        case .missingScheme: "The URL needs a scheme such as server:// or client://."
        case .missingAuthority: "The URL needs an address after the scheme."
        }
    }
}

nonisolated struct InstanceURL: Hashable, Sendable, CustomStringConvertible {
    var role: InstanceRole
    /// Userinfo before `@`: the tunnel password (NodePass) or the shared key (Nowhere).
    var credential: String?
    /// Authority `host[:port]`.
    var tunnel: HostPort
    /// Raw path segments between slashes (percent-decoded).
    var pathSegments: [String]
    var parameters: [URLParameter]
    var fragment: String?

    init(role: InstanceRole,
         credential: String? = nil,
         tunnel: HostPort = HostPort(),
         pathSegments: [String] = [],
         parameters: [URLParameter] = [],
         fragment: String? = nil) {
        self.role = role
        self.credential = credential
        self.tunnel = tunnel
        self.pathSegments = pathSegments
        self.parameters = parameters
        self.fragment = fragment
    }

    // MARK: Parsing

    init(parsing text: String) throws(InstanceURLError) {
        var rest = Substring(text.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !rest.isEmpty else { throw .empty }

        guard let schemeRange = rest.range(of: "://") else { throw .missingScheme }
        let scheme = String(rest[..<schemeRange.lowerBound]).lowercased()
        guard !scheme.isEmpty, scheme.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "+" || $0 == "-" || $0 == "." }) else {
            throw .missingScheme
        }
        role = InstanceRole(rawValue: scheme)
        rest = rest[schemeRange.upperBound...]

        if let hash = rest.firstIndex(of: "#") {
            fragment = Self.decode(rest[rest.index(after: hash)...])
            rest = rest[..<hash]
        } else {
            fragment = nil
        }

        var queryText: Substring = ""
        if let question = rest.firstIndex(of: "?") {
            queryText = rest[rest.index(after: question)...]
            rest = rest[..<question]
        }

        let authorityText: Substring
        let pathText: Substring
        if let slash = rest.firstIndex(of: "/") {
            authorityText = rest[..<slash]
            pathText = rest[rest.index(after: slash)...]
        } else {
            authorityText = rest
            pathText = ""
        }
        guard !authorityText.isEmpty || !pathText.isEmpty else { throw .missingAuthority }

        var hostText = authorityText
        if let at = authorityText.lastIndex(of: "@") {
            credential = Self.decode(authorityText[..<at])
            hostText = authorityText[authorityText.index(after: at)...]
        } else {
            credential = nil
        }
        tunnel = HostPort(parsing: String(hostText))

        pathSegments = pathText.split(separator: "/", omittingEmptySubsequences: true).map { Self.decode($0) }

        parameters = queryText.split(separator: "&", omittingEmptySubsequences: true).compactMap { pair in
            if let equals = pair.firstIndex(of: "=") {
                let key = Self.decode(pair[..<equals])
                guard !key.isEmpty else { return nil }
                return URLParameter(key, Self.decode(pair[pair.index(after: equals)...]))
            }
            let key = Self.decode(pair)
            return key.isEmpty ? nil : URLParameter(key, "")
        }
    }

    // MARK: Serialization

    var description: String { string }

    var string: String {
        var result = role.rawValue + "://"
        if let credential, !credential.isEmpty {
            result += Self.encode(credential, allowed: Self.userinfoAllowed) + "@"
        }
        result += tunnel.description
        for segment in pathSegments {
            result += "/" + Self.encode(segment, allowed: Self.pathAllowed)
        }
        if !parameters.isEmpty {
            result += "?" + parameters.map { parameter in
                let key = Self.encode(parameter.key, allowed: Self.queryAllowed)
                let value = Self.encode(parameter.value, allowed: Self.queryAllowed)
                return "\(key)=\(value)"
            }.joined(separator: "&")
        }
        if let fragment, !fragment.isEmpty {
            result += "#" + Self.encode(fragment, allowed: Self.queryAllowed)
        }
        return result
    }

    // MARK: Parameters

    subscript(parameter key: String) -> String? {
        get { parameters.first { $0.key == key }?.value }
        set {
            if let newValue {
                if let index = parameters.firstIndex(where: { $0.key == key }) {
                    parameters[index].value = newValue
                } else {
                    parameters.append(URLParameter(key, newValue))
                }
            } else {
                parameters.removeAll { $0.key == key }
            }
        }
    }

    func hasParameter(_ key: String) -> Bool {
        parameters.contains { $0.key == key }
    }

    mutating func removeParameter(_ key: String) {
        self[parameter: key] = nil
    }

    /// Keys that appear more than once.
    var duplicateParameterKeys: Set<String> {
        var seen = Set<String>()
        var duplicates = Set<String>()
        for parameter in parameters {
            if !seen.insert(parameter.key).inserted { duplicates.insert(parameter.key) }
        }
        return duplicates
    }

    var flavor: MasterFlavor? { role.flavor }

    // MARK: NodePass path helpers

    /// Target addresses (`host:port[,host:port…]`) for NodePass roles.
    var targets: [HostPort] {
        get {
            guard let first = pathSegments.first else { return [] }
            return first.split(separator: ",", omittingEmptySubsequences: false).map { HostPort(parsing: String($0)) }
        }
        set {
            let joined = newValue.map(\.description).joined(separator: ",")
            if pathSegments.isEmpty {
                pathSegments = joined.isEmpty ? [] : [joined]
            } else {
                pathSegments[0] = joined
                if joined.isEmpty { pathSegments.remove(at: 0) }
            }
        }
    }

    var hasMultipleTargets: Bool { targets.count > 1 }

    // MARK: Nowhere path helpers

    /// Carriers declared in the path for Nowhere roles.
    var carriers: [Carrier] {
        get { pathSegments.compactMap(Carrier.init(parsing:)) }
        set { pathSegments = newValue.map(\.description) }
    }

    // MARK: Encoding helpers

    private static let userinfoAllowed: CharacterSet = {
        var set = CharacterSet.alphanumerics
        set.insert(charactersIn: "-._~!$&'()*+,;=")
        return set
    }()

    private static let pathAllowed: CharacterSet = {
        var set = CharacterSet.alphanumerics
        set.insert(charactersIn: "-._~!$&'()*+,;=:@[]")
        return set
    }()

    private static let queryAllowed: CharacterSet = {
        var set = CharacterSet.alphanumerics
        set.insert(charactersIn: "-._~!$'()*,;:@/[]")
        return set
    }()

    private static func encode(_ text: String, allowed: CharacterSet) -> String {
        text.addingPercentEncoding(withAllowedCharacters: allowed) ?? text
    }

    private static func decode(_ text: Substring) -> String {
        let plusDecoded = text.replacingOccurrences(of: "+", with: " ")
        return plusDecoded.removingPercentEncoding ?? String(text)
    }
}
