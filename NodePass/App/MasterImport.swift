//
//  MasterImport.swift
//  NodePass
//
//  A master description arriving through a deep link, a QR code or the clipboard.
//

import Foundation

struct MasterImport: Hashable, Identifiable {
    var id = UUID()
    var name: String
    var url: String
    var key: String

    /// Parses `np://master?url=<base64>&key=<base64>[&name=<base64>]`.
    init?(deepLink url: URL) {
        guard url.scheme?.lowercased() == NPCore.urlScheme,
              url.host()?.lowercased() == "master",
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems else { return nil }
        func decoded(_ name: String) -> String? {
            guard let raw = items.first(where: { $0.name == name })?.value else { return nil }
            if let data = Data(base64Encoded: raw), let text = String(data: data, encoding: .utf8) { return text }
            return raw.removingPercentEncoding ?? raw
        }
        guard let apiURL = decoded("url"), let key = decoded("key") else { return nil }
        self.name = decoded("name") ?? ""
        self.url = apiURL
        self.key = key
    }

    init(name: String = "", url: String, key: String) {
        self.name = name
        self.url = url
        self.key = key
    }
}
