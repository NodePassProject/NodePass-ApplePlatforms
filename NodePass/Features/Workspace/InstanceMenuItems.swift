//
//  InstanceMenuItems.swift
//  NodePass
//
//  Instance and master operations as menu items. The same views fill the table's context menu
//  and the Instance and Master menus, so both always offer the same operations.
//

#if os(macOS)
import SwiftUI
import SwiftData

extension KeyboardShortcut {
    static let newInstance = KeyboardShortcut("n", modifiers: .command)
    static let newMaster = KeyboardShortcut("n", modifiers: [.command, .shift])
    static let newWindow = KeyboardShortcut("n", modifiers: [.command, .option])
    static let refresh = KeyboardShortcut("r", modifiers: .command)

    static let startInstance = KeyboardShortcut(.return, modifiers: .command)
    static let stopInstance = KeyboardShortcut(".", modifiers: .command)
    static let restartInstance = KeyboardShortcut("r", modifiers: [.command, .shift])
    static let editInstance = KeyboardShortcut("e", modifiers: .command)
    static let duplicateInstance = KeyboardShortcut("d", modifiers: .command)
    static let openConsole = KeyboardShortcut("l", modifiers: .command)
    static let copyInstanceURL = KeyboardShortcut("c", modifiers: [.command, .shift])
    static let deleteInstance = KeyboardShortcut(.delete, modifiers: .command)

    static let editMaster = KeyboardShortcut("e", modifiers: [.command, .option])
}

struct InstanceMenuItems: View {
    /// `nil` when no master workspace has focus; every item is then disabled.
    var workspace: InstanceWorkspace?
    /// Rows the menu acts on; `nil` means the selection.
    var ids: Set<String>? = nil
    /// Main-menu items carry keyboard equivalents; context menus do not.
    var showsShortcuts = false

    @Environment(\.openWindow) private var openWindow

    var body: some View {
        let targets = workspace?.targets(ids) ?? []
        let single = targets.count == 1 ? targets.first : nil

        ForEach(InstanceAction.allCases) { action in
            Button(action.title, systemImage: action.symbolName) { workspace?.run(action, on: ids) }
                .disabled(workspace?.canRun(action, on: ids) != true)
                .keyboardShortcut(shortcut(for: action))
        }

        Divider()

        Button("Edit…", systemImage: "pencil") { single.map { workspace?.edit($0.id) } }
            .disabled(single == nil)
            .keyboardShortcut(showsShortcuts ? .editInstance : nil)
        Button("Duplicate…", systemImage: "plus.square.on.square") { single.map { workspace?.duplicate($0.id) } }
            .disabled(single == nil)
            .keyboardShortcut(showsShortcuts ? .duplicateInstance : nil)
        Toggle("Auto-restart", systemImage: "arrow.trianglehead.clockwise", isOn: Binding(
            get: { workspace?.autoRestart(of: ids) == true },
            set: { workspace?.setAutoRestart($0, on: ids) }))
            .disabled(targets.isEmpty)
        Button("Add Tag…", systemImage: "tag") { workspace?.beginTagging(ids) }
            .disabled(targets.isEmpty)

        Divider()

        Button("Open Console", systemImage: "terminal") {
            if let single, let workspace { openWindow(value: workspace.consoleTarget(for: single.id)) }
        }
        .disabled(single == nil)
        .keyboardShortcut(showsShortcuts ? .openConsole : nil)
        Button(targets.count > 1 ? "Copy \(targets.count) URLs" : "Copy URL", systemImage: "document.on.document") {
            workspace?.copyURLs(ids)
        }
        .disabled(targets.isEmpty)
        .keyboardShortcut(showsShortcuts ? .copyInstanceURL : nil)
        if let single {
            Button("Copy Resolved Config", systemImage: "doc.text") { Clipboard.copy(single.config) }
                .disabled(single.config.isEmpty)
            Button("Copy ID", systemImage: "number") { Clipboard.copy(single.id) }
            if !showsShortcuts {
                ShareLink(item: single.url) {
                    Label("Share URL", systemImage: "square.and.arrow.up")
                }
            }
        }

        Divider()

        Button(targets.count > 1 ? "Delete \(targets.count) Instances…" : "Delete…", systemImage: "trash", role: .destructive) {
            workspace?.delete(ids)
        }
        .disabled(targets.isEmpty)
        .keyboardShortcut(showsShortcuts ? .deleteInstance : nil)
    }

    private func shortcut(for action: InstanceAction) -> KeyboardShortcut? {
        guard showsShortcuts else { return nil }
        return switch action {
        case .start: .startInstance
        case .stop: .stopInstance
        case .restart: .restartInstance
        case .reset: nil
        }
    }
}

struct MasterMenuItems: View {
    var navigation: NavigationModel?
    var workspace: InstanceWorkspace?

    @Environment(\.openWindow) private var openWindow

    var body: some View {
        let master = workspace?.master

        Button("Edit Master…", systemImage: "pencil") { navigation?.masterBeingEdited = master }
            .disabled(master == nil)
            .keyboardShortcut(.editMaster)
        Button(master?.isEnabled == false ? "Enable Master" : "Disable Master", systemImage: master?.isEnabled == false ? "play.circle" : "pause.circle") {
            guard let master else { return }
            master.isEnabled.toggle()
            try? master.modelContext?.save()
        }
        .disabled(master == nil)
        Button("Share…", systemImage: "qrcode") { navigation?.masterBeingShared = master }
            .disabled(master == nil)
        Button("Rotate API Key…", systemImage: "key.horizontal") { navigation?.masterPendingKeyRotation = master }
            .disabled(workspace?.session.connection.isReachable != true)

        Divider()

        Button("Open in New Window", systemImage: "macwindow.badge.plus") {
            if let master { openWindow(value: SidebarItem.master(master.id)) }
        }
        .disabled(master == nil)

        Divider()

        Button("Delete Master…", systemImage: "trash", role: .destructive) { navigation?.masterPendingDeletion = master }
            .disabled(master == nil)
    }
}
#endif
