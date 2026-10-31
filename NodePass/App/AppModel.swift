//
//  AppModel.swift
//  NodePass
//
//  Navigation state and cross-cutting presentation flags.
//

import Foundation
import Observation

enum Tool: String, CaseIterable, Identifiable, Hashable {
    case tcping
    case urlInspector
    case apiConsole

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tcping: "TCP Ping"
        case .urlInspector: "URL Inspector"
        case .apiConsole: "API Console"
        }
    }

    var symbolName: String {
        switch self {
        case .tcping: "dot.radiowaves.left.and.right"
        case .urlInspector: "text.magnifyingglass"
        case .apiConsole: "terminal"
        }
    }

    var summary: String {
        switch self {
        case .tcping: "Measure TCP reachability of any host:port from one of your masters."
        case .urlInspector: "Parse and validate NodePass or Nowhere URLs without touching a master."
        case .apiConsole: "Send raw requests to a master API and inspect the response."
        }
    }
}

enum SidebarItem: Hashable {
    case master(String)
    case tool(Tool)

    var masterID: String? {
        if case .master(let id) = self { return id }
        return nil
    }
}

/// A master description arriving through a deep link or QR code.
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

@Observable
@MainActor
final class AppModel {
    var sidebarSelection: SidebarItem?
    var selectedInstanceID: String?

    var pendingImport: MasterImport?
    var masterBeingEdited: Server?
    var isPresentingNewMaster = false
    var isPresentingSettings = false

    var selectedMasterID: String? { sidebarSelection?.masterID }

    func select(master id: String) {
        sidebarSelection = .master(id)
        selectedInstanceID = nil
    }

    func handle(deepLink url: URL) {
        if let master = MasterImport(deepLink: url) {
            pendingImport = master
            return
        }
        if url.host()?.lowercased() == "server" || url.host()?.lowercased() == "master",
           let id = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "id" })?.value {
            select(master: id)
        }
    }
}
