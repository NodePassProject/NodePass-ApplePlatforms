//
//  SessionConfiguration.swift
//  NodePass
//
//  Tunables of every running `MasterSession`, derived from the user's settings.
//

import Foundation

struct SessionConfiguration: Hashable {
    var liveEventsEnabled = true
    var infoRefreshInterval: TimeInterval = NPCore.Defaults.infoRefreshInterval
    var instancePollInterval: TimeInterval = NPCore.Defaults.instancePollInterval
    var logCapacity: Int = NPCore.Defaults.logBufferSize
}
