//
//  NodePassApp.swift
//  NodePass
//

import SwiftUI
import SwiftData
import TelemetryDeck
import RevenueCat

@main
struct NodePassApp: App {
    @State private var model = AppModel()
    @State private var settings = AppSettings()
    @State private var sessions = SessionStore()
    private let container: ModelContainer

    init() {
        NPCore.registerDefaults()
        do {
            container = try NPData.makeContainer()
        } catch {
            fatalError("Could not create the model container: \(error)")
        }

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
        WindowGroup {
            RootView()
                .preferredColorScheme(settings.theme.colorScheme)
                .environment(model)
                .environment(settings)
                .environment(sessions)
                .modelContainer(container)
                .onOpenURL { url in
                    model.handle(deepLink: url)
                }
        }
    }
}
