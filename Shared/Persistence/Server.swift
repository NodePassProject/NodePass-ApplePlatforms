//
//  Server.swift
//  NodePass
//
//  A persisted **master** (NodePass master API or Nowhere OpenCtrl endpoint).
//
//  The entity keeps its 1.x name `Server` so that records already synced through
//  CloudKit continue to load. Every attribute added in 2.0 is optional, which keeps
//  the change a lightweight, CloudKit-compatible migration.
//

import Foundation
import SwiftData

@Model
final class Server {
    var id: String = UUID().uuidString
    var timestamp: Date = Date()
    var name: String = ""
    var url: String = ""
    var key: String = ""
    var isEnabled: Bool = true

    // MARK: 2.0 additions (all optional for CloudKit schema compatibility)

    /// Raw value of `MasterFlavorSetting`. `nil` means automatic detection.
    var flavorRawValue: String?
    /// Whether self-signed certificates are accepted for this master. `nil` means `true`.
    var trustsSelfSignedCertificatesRaw: Bool?
    /// Free-form operator notes.
    var notes: String?
    /// Manual ordering position; `nil` falls back to creation date.
    var sortIndex: Int?

    init(name: String, url: String, key: String, isEnabled: Bool = true) {
        self.id = UUID().uuidString
        self.timestamp = Date()
        self.name = name
        self.url = url
        self.key = key
        self.isEnabled = isEnabled
    }

    // MARK: Derived

    var flavorSetting: MasterFlavorSetting {
        get { MasterFlavorSetting(rawValue: flavorRawValue ?? "") ?? .automatic }
        set { flavorRawValue = newValue == .automatic ? nil : newValue.rawValue }
    }

    var trustsSelfSignedCertificates: Bool {
        get { trustsSelfSignedCertificatesRaw ?? true }
        set { trustsSelfSignedCertificatesRaw = newValue }
    }

    /// Display name, never empty.
    var displayName: String {
        name.isEmpty ? (host ?? "Untitled") : name
    }

    /// Host component of the API URL, if parseable.
    var host: String? {
        URLComponents(string: url)?.host
    }

    /// Normalized base URL without a trailing slash.
    var baseURL: URL? {
        MasterCredentials.normalizeBaseURL(url)
    }

    var credentials: MasterCredentials? {
        guard let baseURL else { return nil }
        return MasterCredentials(baseURL: baseURL, apiKey: key, trustsSelfSignedCertificates: trustsSelfSignedCertificates)
    }

    /// Flavor resolved from the explicit setting or the URL path (`/v1` vs `/v2`).
    var resolvedFlavor: MasterFlavor? {
        switch flavorSetting {
        case .nodePass: return .nodePass
        case .openCtrl: return .openCtrl
        case .automatic: return baseURL.flatMap(MasterFlavor.infer(fromBaseURL:))
        }
    }

    /// Sendable snapshot for use outside the main actor (widgets, intents).
    var snapshot: MasterSnapshot {
        MasterSnapshot(id: id, name: displayName, url: url, key: key, isEnabled: isEnabled, timestamp: timestamp, trustsSelfSignedCertificates: trustsSelfSignedCertificates)
    }

    /// Deep link that lets another device import this master.
    var shareLink: URL? {
        guard let encodedURL = url.data(using: .utf8)?.base64EncodedString(),
              let encodedKey = key.data(using: .utf8)?.base64EncodedString() else { return nil }
        var components = URLComponents()
        components.scheme = NPCore.urlScheme
        components.host = "master"
        var items = [URLQueryItem(name: "url", value: encodedURL), URLQueryItem(name: "key", value: encodedKey)]
        if !name.isEmpty, let encodedName = name.data(using: .utf8)?.base64EncodedString() {
            items.append(URLQueryItem(name: "name", value: encodedName))
        }
        components.queryItems = items
        return components.url
    }
}

/// Immutable, Sendable copy of a master record.
nonisolated struct MasterSnapshot: Hashable, Sendable, Identifiable {
    let id: String
    let name: String
    let url: String
    let key: String
    let isEnabled: Bool
    let timestamp: Date
    let trustsSelfSignedCertificates: Bool

    var credentials: MasterCredentials? {
        guard let baseURL = MasterCredentials.normalizeBaseURL(url) else { return nil }
        return MasterCredentials(baseURL: baseURL, apiKey: key, trustsSelfSignedCertificates: trustsSelfSignedCertificates)
    }
}

/// User-facing flavor choice stored on a master.
nonisolated enum MasterFlavorSetting: String, CaseIterable, Sendable {
    case automatic
    case nodePass
    case openCtrl

    var title: String {
        switch self {
        case .automatic: "Automatic"
        case .nodePass: "NodePass"
        case .openCtrl: "Nowhere (OpenCtrl)"
        }
    }
}
