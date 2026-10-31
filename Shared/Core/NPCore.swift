//
//  NPCore.swift
//  NodePass
//
//  App-wide constants and the shared UserDefaults suite.
//

import Foundation

nonisolated enum NPCore {
    /// App Group shared between the app and its extensions.
    static let appGroupIdentifier = "group.com.argsment.NodePass"

    /// Custom URL scheme handled by the app (`np://master?...`).
    static let urlScheme = "np"

    /// The master stores its API key in a pseudo-instance with this fixed ID.
    static let apiKeyInstanceID = "********"

    /// Maximum length the master accepts for aliases, tag keys/values and peer fields.
    static let maxValueLength = 256

    /// Shared defaults suite (falls back to standard defaults if the group is unavailable).
    /// `UserDefaults` is documented as thread-safe; the unsafe marker only silences the global-state check.
    nonisolated(unsafe) static let userDefaults: UserDefaults = UserDefaults(suiteName: appGroupIdentifier) ?? .standard

    enum DefaultsKey {
        static let appTheme = "NPAppTheme"
        static let masterSortKey = "NPServerSortIndicator"
        static let masterSortOrder = "NPServerSortOrder"
        static let infoRefreshInterval = "NPInfoRefreshInterval"
        static let instancePollInterval = "NPInstancePollInterval"
        static let liveEventsEnabled = "NPLiveEventsEnabled"
        static let logBufferSize = "NPLogBufferSize"
        static let analyticsEnabled = "NPAnalyticsEnabled"
        static let hapticsEnabled = "NPHapticsEnabled"
        static let showInstanceIdentifiers = "NPShowInstanceIdentifiers"
        static let confirmDestructiveActions = "NPConfirmDestructiveActions"
        static let instanceDensity = "NPInstanceDensity"
    }

    enum Defaults {
        static let infoRefreshInterval: Double = 5
        static let instancePollInterval: Double = 10
        static let logBufferSize: Int = 500
    }

    static func registerDefaults() {
        userDefaults.register(defaults: [
            DefaultsKey.appTheme: "automatic",
            DefaultsKey.masterSortKey: "date",
            DefaultsKey.masterSortOrder: "ascending",
            DefaultsKey.infoRefreshInterval: Defaults.infoRefreshInterval,
            DefaultsKey.instancePollInterval: Defaults.instancePollInterval,
            DefaultsKey.liveEventsEnabled: true,
            DefaultsKey.logBufferSize: Defaults.logBufferSize,
            DefaultsKey.analyticsEnabled: true,
            DefaultsKey.hapticsEnabled: true,
            DefaultsKey.showInstanceIdentifiers: true,
            DefaultsKey.confirmDestructiveActions: true,
            DefaultsKey.instanceDensity: "regular",
        ])
    }
}
