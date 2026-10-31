//
//  IntentNavigator.swift
//  NodePass Watch App
//
//  Where foreground intents send the watch app. watchOS has neither `onAppIntentExecution` (iOS)
//  nor windows that handle the app's own links (macOS), so an intent hands its destination to this
//  object and the root view navigates when it changes.
//

import Foundation
import Observation

/// A screen of the watch app, as the navigation stack pushes it.
enum WatchRoute: Hashable {
    case master(String)
    case instance(masterID: String, instanceID: String)

    /// The path to this screen from the master list.
    var path: [WatchRoute] {
        switch self {
        case .master:
            [self]
        case .instance(let masterID, _):
            [.master(masterID), self]
        }
    }

    /// The destination of an `np://master?id=…[&instance=…]` link, as the widgets open them.
    init?(deepLink url: URL) {
        guard url.scheme?.lowercased() == NPCore.urlScheme,
              url.host()?.lowercased() == "master",
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
              let masterID = items.first(where: { $0.name == "id" })?.value else { return nil }
        if let instanceID = items.first(where: { $0.name == "instance" })?.value {
            self = .instance(masterID: masterID, instanceID: instanceID)
        } else {
            self = .master(masterID)
        }
    }
}

@Observable
@MainActor
final class IntentNavigator {
    /// The destination of the last foreground intent, until the root view takes it.
    private(set) var pending: WatchRoute?

    func show(master id: String) {
        pending = .master(id)
    }

    func show(instance id: String, on masterID: String) {
        pending = .instance(masterID: masterID, instanceID: id)
    }

    func takePending() -> WatchRoute? {
        defer { pending = nil }
        return pending
    }
}
