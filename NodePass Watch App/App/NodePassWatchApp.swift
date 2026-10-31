//
//  NodePassWatchApp.swift
//  NodePass Watch App
//
//  The Apple Watch app: the masters mirrored from the iPhone, each with a live session while the
//  app is on screen, and the same App Intents as the other platforms (minus the tools).
//

import AppIntents
import SwiftUI
import WidgetKit

@main
struct NodePassWatchApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var sessions: SessionStore
    @State private var mirror: MasterMirror
    @State private var bridge: WatchBridge
    @State private var navigator: IntentNavigator

    init() {
        NPCore.registerDefaults()
        let sessions = SessionStore()
        let mirror = MasterMirror.shared
        let navigator = IntentNavigator()
        _sessions = State(initialValue: sessions)
        _mirror = State(initialValue: mirror)
        _bridge = State(initialValue: WatchBridge(mirror: mirror))
        _navigator = State(initialValue: navigator)

        // App Intents resolve these from here, whether the app is on screen or Siri and Shortcuts
        // run an intent in the background.
        let masters = MasterStore()
        let intentModel = IntentModel(masters: masters, sessions: sessions)
        AppDependencyManager.shared.add(dependency: masters)
        AppDependencyManager.shared.add(dependency: intentModel)
        AppDependencyManager.shared.add(dependency: navigator)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(sessions)
                .environment(mirror)
                .environment(bridge)
                .environment(navigator)
        }
        .onChange(of: scenePhase, initial: true) { oldPhase, newPhase in
            // Sessions stream while the app is on screen, the dimmed Always On display included.
            if newPhase == .background { sessions.deactivate() } else { sessions.activate() }
            if newPhase == .active { bridge.requestMastersIfNeeded() }
            // Leaving the app is when widgets fall behind what the user just changed.
            if oldPhase == .active, newPhase != .active { WidgetCenter.shared.reloadAllTimelines() }
        }
        .onChange(of: mirror.snapshots, initial: true) { _, snapshots in
            sessions.sync(with: snapshots, configuration: .watch)
            // Siri learns the master names for the App Shortcut phrases.
            NodePassShortcuts.updateAppShortcutParameters()
        }
    }
}

extension SessionConfiguration {
    /// Watch sessions run only while the app is on screen, so they ask less often than the phone
    /// and keep fewer log lines.
    static let watch = SessionConfiguration(liveEventsEnabled: true, infoRefreshInterval: 10, instancePollInterval: 15, logCapacity: 50)
}
