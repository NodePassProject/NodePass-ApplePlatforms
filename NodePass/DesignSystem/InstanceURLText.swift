//
//  InstanceURLText.swift
//  NodePass
//
//  An instance URL as monospaced text colored by part, so it reads as structure: the scheme in
//  the role's tint, the credential dimmed (or masked), separators and keys receding behind the
//  values. Parts the caller leaves unstyled take the surrounding foreground style.
//

import SwiftUI

struct InstanceURLText: View {
    var url: String
    var masksCredential = false
    var font: Font = .code(.callout)

    var body: some View {
        InstanceURLText.text(for: url, masksCredential: masksCredential)
            .font(font)
    }

    /// The colored text, for callers that compose it with other `Text`.
    static func text(for url: String, masksCredential: Bool = false) -> Text {
        guard let schemeRange = url.range(of: "://") else { return Text(url) }
        let scheme = String(url[..<schemeRange.lowerBound])
        let role = InstanceRole(rawValue: scheme)
        var rest = url[schemeRange.upperBound...]

        var fragment: Substring?
        if let hash = rest.firstIndex(of: "#") {
            fragment = rest[rest.index(after: hash)...]
            rest = rest[..<hash]
        }
        var query: Substring?
        if let question = rest.firstIndex(of: "?") {
            query = rest[rest.index(after: question)...]
            rest = rest[..<question]
        }
        var path: Substring = ""
        if let slash = rest.firstIndex(of: "/") {
            path = rest[slash...]
            rest = rest[..<slash]
        }
        var credential: Substring?
        if let at = rest.lastIndex(of: "@") {
            credential = rest[..<at]
            rest = rest[rest.index(after: at)...]
        }

        var result = Text(scheme + "://")
            .foregroundStyle(role.tint)
            .fontWeight(.semibold)
        if let credential {
            let shown = masksCredential ? String(repeating: "•", count: min(max(credential.count, 4), 8)) : String(credential)
            result = result + Text(shown).foregroundStyle(.secondary) + Text("@").foregroundStyle(.tertiary)
        }
        result = result + Text(String(rest))
        if !path.isEmpty {
            result = result + Text(String(path))
        }
        if let query {
            result = result + Text("?").foregroundStyle(.tertiary)
            for (index, pair) in query.split(separator: "&", omittingEmptySubsequences: false).enumerated() {
                if index > 0 { result = result + Text("&").foregroundStyle(.tertiary) }
                if let equals = pair.firstIndex(of: "=") {
                    result = result
                        + Text(String(pair[..<equals])).foregroundStyle(.secondary)
                        + Text("=").foregroundStyle(.tertiary)
                        + Text(String(pair[pair.index(after: equals)...]))
                } else {
                    result = result + Text(String(pair)).foregroundStyle(.secondary)
                }
            }
        }
        if let fragment {
            result = result + Text("#").foregroundStyle(.tertiary) + Text(String(fragment)).foregroundStyle(.secondary)
        }
        return result
    }
}
