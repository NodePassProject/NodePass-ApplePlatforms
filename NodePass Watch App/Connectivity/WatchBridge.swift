//
//  WatchBridge.swift
//  NodePass Watch App
//
//  Receives the masters from the iPhone. The phone pushes its list as the application context
//  whenever it changes, which arrives even while this app is not running; the watch asks for the
//  list on its first launch and on request, which wakes the iPhone app in the background.
//

import Foundation
import Observation
import OSLog
import WatchConnectivity
import WidgetKit

nonisolated private let bridgeLog = Logger(subsystem: "com.argsment.NodePass", category: "WatchBridge")

@Observable
@MainActor
final class WatchBridge: NSObject {
    /// Whether NodePass is installed on the paired iPhone; without it there is nothing to mirror.
    private(set) var isCompanionAppInstalled = true
    /// Whether the iPhone can answer a request right now.
    private(set) var isReachable = false
    private(set) var isRequesting = false
    private(set) var lastRequestError: String?

    private let mirror: MasterMirror
    private var requestPending = false

    init(mirror: MasterMirror) {
        self.mirror = mirror
        super.init()
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    /// Asks the phone for its list when nothing has arrived yet or the copy is a day old. The
    /// phone pushes changes on its own, so this is a safety net rather than the usual path.
    func requestMastersIfNeeded() {
        let isStale = mirror.receivedAt.map { Date.now.timeIntervalSince($0) > 24 * 60 * 60 } ?? true
        if mirror.isEmpty || isStale { requestMasters() }
    }

    func requestMasters() {
        let session = WCSession.default
        guard session.activationState == .activated else {
            requestPending = true
            return
        }
        guard session.isCompanionAppInstalled else {
            isCompanionAppInstalled = false
            return
        }
        guard !isRequesting else { return }
        isRequesting = true
        lastRequestError = nil
        bridgeLog.debug("asking the phone for its masters (reachable: \(session.isReachable))")
        // The handlers run on a background queue; only Sendable values cross back.
        session.sendMessage(MasterMirrorPayload.request, replyHandler: { @Sendable reply in
            let payload = MasterMirrorPayload.payload(from: reply)
            Task { @MainActor in
                self.finishRequest(with: payload, error: payload == nil ? "The iPhone sent no masters." : nil)
            }
        }, errorHandler: { @Sendable error in
            let message = Self.describe(error)
            Task { @MainActor in
                self.finishRequest(with: nil, error: message)
            }
        })
    }

    private func finishRequest(with payload: MasterMirrorPayload?, error: String?) {
        isRequesting = false
        lastRequestError = error
        if let payload {
            bridgeLog.debug("the phone answered with \(payload.masters.count) masters")
            apply(payload)
        } else {
            bridgeLog.error("request failed: \(error ?? "no payload", privacy: .public)")
        }
    }

    private func apply(_ payload: MasterMirrorPayload) {
        if mirror.replace(with: payload) {
            bridgeLog.debug("mirrored \(payload.masters.count) masters from the phone")
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    nonisolated private static func describe(_ error: any Error) -> String {
        switch (error as? WCError)?.code {
        case .notReachable: "Your iPhone is not reachable."
        case .companionAppNotInstalled: "NodePass is not installed on your iPhone."
        case .deliveryFailed, .transferTimedOut: "Your iPhone did not answer."
        default: error.localizedDescription
        }
    }
}

extension WatchBridge: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?) {
        if let error {
            bridgeLog.error("activation failed: \(error.localizedDescription, privacy: .public)")
        }
        // The last context the phone sent, delivered even while this app was not running.
        let payload = MasterMirrorPayload.payload(from: session.receivedApplicationContext)
        let companionInstalled = session.isCompanionAppInstalled
        let reachable = session.isReachable
        bridgeLog.debug("activated: companion installed \(companionInstalled), reachable \(reachable), stored context \(payload?.masters.count ?? -1)")
        Task { @MainActor in
            isCompanionAppInstalled = companionInstalled
            isReachable = reachable
            if let payload { apply(payload) }
            if requestPending {
                requestPending = false
                requestMasters()
            }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let payload = MasterMirrorPayload.payload(from: applicationContext) else { return }
        Task { @MainActor in apply(payload) }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        Task { @MainActor in isReachable = reachable }
    }

    nonisolated func sessionCompanionAppInstalledDidChange(_ session: WCSession) {
        let installed = session.isCompanionAppInstalled
        Task { @MainActor in
            isCompanionAppInstalled = installed
            if installed { requestMasters() }
        }
    }
}
