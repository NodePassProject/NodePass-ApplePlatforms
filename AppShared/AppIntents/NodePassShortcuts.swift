//
//  NodePassShortcuts.swift
//  NodePass
//
//  The App Shortcuts: ready to use in Shortcuts, Spotlight and Siri without setup. Phrases that
//  name an instance or master rely on `updateAppShortcutParameters()`, which the apps call
//  whenever the known masters and instances change (`SystemEntitySync` on iOS and macOS, the
//  watch app whenever its mirrored masters change). Compiled into the iPhone/Mac app and the
//  watch app alike; the tools live only in the former.
//

import AppIntents

nonisolated struct NodePassShortcuts: AppShortcutsProvider {
    static let shortcutTileColor: ShortcutTileColor = .blue

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: GetMasterStatusIntent(),
            phrases: [
                "Check \(\.$master) in \(.applicationName)",
                "Check a master in \(.applicationName)",
                "Get \(\.$master) status in \(.applicationName)",
                "Is \(\.$master) online in \(.applicationName)",
            ],
            shortTitle: "Check Master",
            systemImageName: "server.rack"
        )
        AppShortcut(
            intent: GetInstanceStatusIntent(),
            phrases: [
                "Get status of \(\.$instance) in \(.applicationName)",
                "Is \(\.$instance) running in \(.applicationName)",
                "Check an instance in \(.applicationName)",
            ],
            shortTitle: "Instance Status",
            systemImageName: "waveform.path.ecg"
        )
        AppShortcut(
            intent: StartInstanceIntent(),
            phrases: [
                "Start \(\.$instance) in \(.applicationName)",
                "Start an instance in \(.applicationName)",
            ],
            shortTitle: "Start Instance",
            systemImageName: "play.fill"
        )
        AppShortcut(
            intent: StopInstanceIntent(),
            phrases: [
                "Stop \(\.$instance) in \(.applicationName)",
                "Stop an instance in \(.applicationName)",
            ],
            shortTitle: "Stop Instance",
            systemImageName: "stop.fill"
        )
        AppShortcut(
            intent: RestartInstanceIntent(),
            phrases: [
                "Restart \(\.$instance) in \(.applicationName)",
                "Restart an instance in \(.applicationName)",
            ],
            shortTitle: "Restart Instance",
            systemImageName: "arrow.clockwise"
        )
        AppShortcut(
            intent: OpenMasterIntent(),
            phrases: [
                "Open \(\.$target) in \(.applicationName)",
                "Open a master in \(.applicationName)",
                "Show \(\.$target) in \(.applicationName)",
            ],
            shortTitle: "Open Master",
            systemImageName: "sidebar.left"
        )
        AppShortcut(
            intent: OpenInstanceIntent(),
            phrases: [
                "Open \(\.$target) in \(.applicationName)",
                "Open an instance in \(.applicationName)",
                "Show \(\.$target) in \(.applicationName)",
            ],
            shortTitle: "Open Instance",
            systemImageName: "square.stack.3d.up"
        )
        #if !os(watchOS)
        AppShortcut(
            intent: OpenToolIntent(),
            phrases: [
                "Open \(\.$tool) in \(.applicationName)",
                "Open a tool in \(.applicationName)",
            ],
            shortTitle: "Open Tool",
            systemImageName: "wrench.and.screwdriver"
        )
        #endif
        AppShortcut(
            intent: TCPingIntent(),
            phrases: [
                "Run a TCP ping in \(.applicationName)",
                "Test a connection in \(.applicationName)",
            ],
            shortTitle: "TCP Ping",
            systemImageName: "dot.radiowaves.left.and.right"
        )
    }
}
