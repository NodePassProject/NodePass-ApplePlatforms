//
//  AppSettings.swift
//  NodePass
//
//  Observable facade over the shared UserDefaults suite.
//

import Foundation
import Observation
import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case automatic, light, dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic: "Automatic"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .automatic: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

enum InstanceDensity: String, CaseIterable, Identifiable {
    case compact, regular

    var id: String { rawValue }

    var title: String {
        switch self {
        case .compact: "Compact"
        case .regular: "Regular"
        }
    }
}

@Observable
@MainActor
final class AppSettings {
    private let defaults: UserDefaults

    var theme: AppTheme { didSet { defaults.set(theme.rawValue, forKey: NPCore.DefaultsKey.appTheme) } }
    var liveEventsEnabled: Bool { didSet { defaults.set(liveEventsEnabled, forKey: NPCore.DefaultsKey.liveEventsEnabled) } }
    var infoRefreshInterval: Double { didSet { defaults.set(infoRefreshInterval, forKey: NPCore.DefaultsKey.infoRefreshInterval) } }
    var instancePollInterval: Double { didSet { defaults.set(instancePollInterval, forKey: NPCore.DefaultsKey.instancePollInterval) } }
    var logBufferSize: Int { didSet { defaults.set(logBufferSize, forKey: NPCore.DefaultsKey.logBufferSize) } }
    var analyticsEnabled: Bool { didSet { defaults.set(analyticsEnabled, forKey: NPCore.DefaultsKey.analyticsEnabled) } }
    var hapticsEnabled: Bool { didSet { defaults.set(hapticsEnabled, forKey: NPCore.DefaultsKey.hapticsEnabled) } }
    var showInstanceIdentifiers: Bool { didSet { defaults.set(showInstanceIdentifiers, forKey: NPCore.DefaultsKey.showInstanceIdentifiers) } }
    var confirmDestructiveActions: Bool { didSet { defaults.set(confirmDestructiveActions, forKey: NPCore.DefaultsKey.confirmDestructiveActions) } }
    var instanceDensity: InstanceDensity { didSet { defaults.set(instanceDensity.rawValue, forKey: NPCore.DefaultsKey.instanceDensity) } }
    /// macOS: keep a status item in the menu bar, which also keeps sessions live without windows.
    var showsMenuBarExtra: Bool { didSet { defaults.set(showsMenuBarExtra, forKey: NPCore.DefaultsKey.showsMenuBarExtra) } }

    init(defaults: UserDefaults = NPCore.userDefaults) {
        self.defaults = defaults
        theme = AppTheme(rawValue: defaults.string(forKey: NPCore.DefaultsKey.appTheme) ?? "") ?? .automatic
        liveEventsEnabled = defaults.object(forKey: NPCore.DefaultsKey.liveEventsEnabled) as? Bool ?? true
        infoRefreshInterval = defaults.object(forKey: NPCore.DefaultsKey.infoRefreshInterval) as? Double ?? NPCore.Defaults.infoRefreshInterval
        instancePollInterval = defaults.object(forKey: NPCore.DefaultsKey.instancePollInterval) as? Double ?? NPCore.Defaults.instancePollInterval
        logBufferSize = defaults.object(forKey: NPCore.DefaultsKey.logBufferSize) as? Int ?? NPCore.Defaults.logBufferSize
        analyticsEnabled = defaults.object(forKey: NPCore.DefaultsKey.analyticsEnabled) as? Bool ?? true
        hapticsEnabled = defaults.object(forKey: NPCore.DefaultsKey.hapticsEnabled) as? Bool ?? true
        showInstanceIdentifiers = defaults.object(forKey: NPCore.DefaultsKey.showInstanceIdentifiers) as? Bool ?? true
        confirmDestructiveActions = defaults.object(forKey: NPCore.DefaultsKey.confirmDestructiveActions) as? Bool ?? true
        instanceDensity = InstanceDensity(rawValue: defaults.string(forKey: NPCore.DefaultsKey.instanceDensity) ?? "") ?? .regular
        showsMenuBarExtra = defaults.object(forKey: NPCore.DefaultsKey.showsMenuBarExtra) as? Bool ?? true
    }

    /// The part of the settings that running sessions depend on.
    var sessionConfiguration: SessionConfiguration {
        SessionConfiguration(
            liveEventsEnabled: liveEventsEnabled,
            infoRefreshInterval: infoRefreshInterval,
            instancePollInterval: instancePollInterval,
            logCapacity: logBufferSize
        )
    }
}
