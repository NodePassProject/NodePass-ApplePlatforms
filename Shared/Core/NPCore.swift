//
//  NPCore.swift
//  NodePass
//
//  App-wide constants and the shared UserDefaults suite.
//

import Foundation
#if os(macOS)
import Security
#endif

nonisolated enum NPCore {
    /// App Group shared between the app and its extensions.
    static let appGroupIdentifier = "group.com.argsment.NodePass"

    /// Custom URL scheme handled by the app (`np://master?...`).
    static let urlScheme = "np"

    /// The master stores its API key in a pseudo-instance with this fixed ID.
    static let apiKeyInstanceID = "********"

    /// Maximum length the master accepts for aliases, tag keys/values and peer fields.
    static let maxValueLength = 256

    /// Whether this process may use the App Group. iOS reports it through the container URL; macOS
    /// returns group container URLs even to unentitled processes (and may ask the user for access),
    /// so the entitlement itself is checked there.
    static let isAppGroupAvailable: Bool = {
        #if os(macOS)
        guard let task = SecTaskCreateFromSelf(nil),
              let groups = SecTaskCopyValueForEntitlement(task, "com.apple.security.application-groups" as CFString, nil) as? [String] else {
            return false
        }
        return groups.contains(appGroupIdentifier)
        #else
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) != nil
        #endif
    }()

    /// Shared defaults suite (falls back to standard defaults if the group is unavailable).
    /// `UserDefaults` is documented as thread-safe; the unsafe marker only silences the global-state check.
    nonisolated(unsafe) static let userDefaults: UserDefaults = {
        #if os(macOS)
        guard isAppGroupAvailable else { return .standard }
        #endif
        return UserDefaults(suiteName: appGroupIdentifier) ?? .standard
    }()

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
        static let instanceLayout = "NPInstanceLayout"
        static let instanceSortKey = "NPInstanceSortKey"
        static let instanceSortAscending = "NPInstanceSortAscending"
        static let instanceGrouping = "NPInstanceGrouping"
        static let instanceGroupingTag = "NPInstanceGroupingTag"
        static let showsMenuBarExtra = "NPShowsMenuBarExtra"
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
            DefaultsKey.instanceLayout: "automatic",
            DefaultsKey.showsMenuBarExtra: true,
        ])
    }
}
