//
//  NavigationModel.swift
//  NodePass
//
//  Navigation and presentation state of one window. Each window owns its own model, so several
//  windows can show different masters side by side.
//

import Foundation
import Observation

nonisolated enum Tool: String, CaseIterable, Identifiable, Hashable, Codable, Sendable {
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

/// What a window shows. Codable so the window scene can restore it.
enum SidebarItem: Hashable, Codable {
    case master(String)
    case tool(Tool)

    var masterID: String? {
        if case .master(let id) = self { return id }
        return nil
    }
}

@Observable
@MainActor
final class NavigationModel {
    var sidebarSelection: SidebarItem? {
        didSet {
            if oldValue?.masterID != sidebarSelection?.masterID { selectedInstanceIDs = [] }
        }
    }

    /// Selected instances of the selected master. The macOS table selects many; the list-based
    /// layout uses `selectedInstanceID`.
    var selectedInstanceIDs: Set<String> = []

    /// Whether the macOS inspector column is shown.
    var isInspectorPresented = true

    // Presentations shared by the sidebar, the master overview and the menu bar commands.
    var pendingImport: MasterImport?
    var isPresentingNewMaster = false
    var masterBeingEdited: Server?
    var masterBeingShared: Server?
    var masterPendingDeletion: Server?
    var masterPendingKeyRotation: Server?
    #if os(iOS)
    var isPresentingSettings = false
    #endif

    var selectedMasterID: String? { sidebarSelection?.masterID }

    /// Single-instance view of the selection.
    var selectedInstanceID: String? {
        get { selectedInstanceIDs.count == 1 ? selectedInstanceIDs.first : nil }
        set { selectedInstanceIDs = newValue.map { [$0] } ?? [] }
    }

    func select(master id: String) {
        sidebarSelection = .master(id)
        selectedInstanceIDs = []
    }

    func select(instance instanceID: String, on masterID: String) {
        if sidebarSelection != .master(masterID) { sidebarSelection = .master(masterID) }
        selectedInstanceIDs = [instanceID]
    }

    func handle(deepLink url: URL) {
        if let master = MasterImport(deepLink: url) {
            pendingImport = master
            return
        }
        guard let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
              let id = items.first(where: { $0.name == "id" })?.value else { return }
        switch url.host()?.lowercased() {
        case "server", "master":
            if let instanceID = items.first(where: { $0.name == "instance" })?.value {
                select(instance: instanceID, on: id)
            } else {
                select(master: id)
            }
        case "tool":
            if let tool = Tool(rawValue: id) { sidebarSelection = .tool(tool) }
        default:
            break
        }
    }
}
