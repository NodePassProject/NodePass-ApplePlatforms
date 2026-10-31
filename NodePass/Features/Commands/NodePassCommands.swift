//
//  NodePassCommands.swift
//  NodePass
//
//  The macOS menu bar. Commands act on the key window through focused values, so each window's
//  menus reflect its own selection and nothing is enabled while Settings or a console has focus.
//

#if os(macOS)
import SwiftUI

extension FocusedValues {
    /// Navigation state of the key main window.
    @Entry var navigationModel: NavigationModel?
    /// The master workspace of the key main window, when it shows a master.
    @Entry var instanceWorkspace: InstanceWorkspace?
}

struct NodePassCommands: Commands {
    @FocusedValue(\.navigationModel) private var navigation
    @FocusedValue(\.instanceWorkspace) private var workspace
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        SidebarCommands()
        InspectorCommands()
        ToolbarCommands()

        CommandGroup(replacing: .newItem) {
            Button("New Instance…") { workspace?.createInstance() }
                .keyboardShortcut(.newInstance)
                .disabled(workspace == nil)
            Button("New Master…") { navigation?.isPresentingNewMaster = true }
                .keyboardShortcut(.newMaster)
                .disabled(navigation == nil)
            Divider()
            Button("New Window") { openWindow(id: SceneID.main) }
                .keyboardShortcut(.newWindow)
        }

        CommandGroup(before: .sidebar) {
            Button("Refresh") { workspace?.refresh() }
                .keyboardShortcut(.refresh)
                .disabled(workspace == nil)
            Divider()
        }

        CommandMenu("Instance") {
            InstanceMenuItems(workspace: workspace, showsShortcuts: true)
        }

        CommandMenu("Master") {
            MasterMenuItems(navigation: navigation, workspace: workspace)
        }

        CommandGroup(replacing: .help) {
            ForEach(ExternalLink.allCases) { link in
                Link(link.title, destination: link.url)
            }
        }
    }
}
#endif
