//
//  NodePassApp.swift
//  NodePass
//

import AppIntents
import SwiftUI
import SwiftData
import WidgetKit
import TelemetryDeck
import RevenueCat

@main
struct NodePassApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var settings = AppSettings()
    @State private var sessions: SessionStore
    private let container: ModelContainer

    init() {
        NPCore.registerDefaults()
        do {
            container = try NPData.makeContainer()
        } catch {
            fatalError("Could not create the model container: \(error)")
        }

        // App Intents resolve these from here, whether the app is on screen or the system launched
        // it in the background for Siri, Shortcuts or Spotlight.
        let sessions = SessionStore()
        _sessions = State(initialValue: sessions)
        let masters = MasterStore(container: container)
        let intentModel = IntentModel(masters: masters, sessions: sessions)
        AppDependencyManager.shared.add(dependency: masters)
        AppDependencyManager.shared.add(dependency: intentModel)
        #if os(macOS)
        let navigator = IntentNavigator()
        AppDependencyManager.shared.add(dependency: navigator)
        #endif

        let analyticsEnabled = NPCore.userDefaults.object(forKey: NPCore.DefaultsKey.analyticsEnabled) as? Bool ?? true
        if analyticsEnabled {
            TelemetryDeck.initialize(config: TelemetryDeck.Config(appID: "041ED631-4E1A-4B17-B701-F378A17BD3D7"))
        }

        if let revenueCatAPIKey = Bundle.main.object(forInfoDictionaryKey: "RevenueCatAPIKey") as? String,
           !revenueCatAPIKey.isEmpty, !revenueCatAPIKey.hasPrefix("$(") {
            Purchases.configure(withAPIKey: revenueCatAPIKey)
        }
    }

    var body: some Scene {
        WindowGroup(id: SceneID.main, for: SidebarItem.self) { $selection in
            RootView(windowSelection: $selection)
                .appEnvironment(settings: settings, sessions: sessions, container: container)
        }
        #if os(macOS)
        .defaultSize(width: 1360, height: 820)
        .commands { NodePassCommands() }
        #endif
        .onChange(of: sessionsShouldRun, initial: true) { _, shouldRun in
            if shouldRun { sessions.activate() } else { sessions.deactivate() }
        }
        .onChange(of: settings.sessionConfiguration) { _, configuration in
            sessions.apply(configuration)
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            // Leaving the app is when widgets fall behind what the user just changed.
            if oldPhase == .active, newPhase != .active {
                WidgetCenter.shared.reloadAllTimelines()
            }
        }

        #if os(macOS)
        WindowGroup("Console", id: SceneID.console, for: ConsoleTarget.self) { $target in
            ConsoleWindow(target: target)
                .appEnvironment(settings: settings, sessions: sessions, container: container)
        }
        .defaultSize(width: 900, height: 560)

        Settings {
            SettingsWindow()
                .appEnvironment(settings: settings, sessions: sessions, container: container)
        }

        MenuBarExtra(isInserted: $settings.showsMenuBarExtra) {
            MenuBarStatusView()
                .appEnvironment(settings: settings, sessions: sessions, container: container)
        } label: {
            MenuBarStatusLabel(sessions: sessions)
        }
        .menuBarExtraStyle(.window)
        #endif
    }

    /// Sessions stream while any window is on screen, and on macOS for as long as the menu bar
    /// status item is shown, so it reflects live health without a window.
    private var sessionsShouldRun: Bool {
        #if os(macOS)
        scenePhase != .background || settings.showsMenuBarExtra
        #else
        scenePhase != .background
        #endif
    }
}

/// Identifiers of the scenes that can be opened programmatically.
enum SceneID {
    static let main = "main"
    static let console = "console"
}
