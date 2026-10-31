//
//  WatchBridge.swift
//  NodePass
//
//  Sends the saved masters to the Apple Watch app. iPhone only: Watch Connectivity exists nowhere
//  else, and the watch mirrors the phone it is paired with. The list goes out as the application
//  context, which the system delivers even while the watch app is not running, and again as the
//  reply whenever the watch asks (that request wakes this app in the background if needed).
//

#if os(iOS)
import Foundation
import OSLog
import SwiftData
import SwiftUI
import WatchConnectivity

nonisolated private let watchLog = Logger(subsystem: "com.argsment.NodePass", category: "WatchBridge")

@MainActor
final class WatchBridge: NSObject {
    private let masters: MasterStore

    /// Activated once at launch. `nil` on iPad, where no watch can be paired.
    private var session: WCSession? {
        WCSession.isSupported() ? WCSession.default : nil
    }

    init(masters: MasterStore) {
        self.masters = masters
        super.init()
        guard let session else { return }
        session.delegate = self
        session.activate()
    }

    /// Sends the list as it is now. Called whenever the saved masters change and whenever the
    /// session (re)activates or a watch app appears.
    func publish() {
        publish(payload: currentPayload())
    }

    private func publish(payload: MasterMirrorPayload) {
        guard let session, session.activationState == .activated else { return }
        guard session.isPaired, session.isWatchAppInstalled else { return }
        do {
            try session.updateApplicationContext(payload.message())
            watchLog.debug("published \(payload.masters.count) masters to the watch")
        } catch {
            watchLog.error("application context failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func currentPayload() -> MasterMirrorPayload {
        MasterMirrorPayload(masters: (try? masters.snapshots()) ?? [])
    }
}

extension WatchBridge: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?) {
        if let error {
            watchLog.error("activation failed: \(error.localizedDescription, privacy: .public)")
        }
        guard activationState == .activated else { return }
        Task { @MainActor in publish() }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    /// The user switched to another watch; the session has to be activated again for it.
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    /// Pairing or the watch app's installation changed: a freshly installed watch app gets the
    /// list right away.
    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in publish() }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        guard MasterMirrorPayload.isRequest(message) else {
            replyHandler([:])
            return
        }
        watchLog.debug("the watch asked for the masters")
        // The reply handler may be called from any thread; the list has to be read on the main actor.
        nonisolated(unsafe) let reply = replyHandler
        Task { @MainActor in
            let payload = currentPayload()
            reply((try? payload.message()) ?? [:])
            // Keep the stored context current too, so the watch widgets pick the list up even if
            // the watch app is gone before it saved the reply.
            publish(payload: payload)
        }
    }
}

// MARK: - SwiftUI

extension EnvironmentValues {
    @Entry var watchBridge: WatchBridge?
}

extension View {
    /// Keeps the Apple Watch's copy of the masters current while this view is on screen.
    func keepsWatchInSync() -> some View {
        modifier(WatchSyncModifier())
    }
}

private struct WatchSyncModifier: ViewModifier {
    @Environment(\.watchBridge) private var bridge
    @Query(sort: \Server.timestamp) private var masters: [Server]

    func body(content: Content) -> some View {
        content.task(id: fingerprint) {
            bridge?.publish()
        }
    }

    /// Changes whenever anything a snapshot carries changes.
    private var fingerprint: [String] {
        masters.map { "\($0.id)|\($0.name)|\($0.url)|\($0.key)|\($0.isEnabled)|\($0.flavorRawValue ?? "")|\($0.trustsSelfSignedCertificates)|\($0.timestamp.timeIntervalSince1970)" }
    }
}
#endif
