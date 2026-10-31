//
//  ConsoleWindow.swift
//  NodePass
//
//  A separate macOS window following the log of one instance, so several consoles can be tiled
//  next to the main window.
//

#if os(macOS)
import SwiftUI
import SwiftData

/// Identifies the instance a console window follows. Codable so the window is restored on launch.
struct ConsoleTarget: Codable, Hashable {
    var masterID: String
    var instanceID: String
}

struct ConsoleWindow: View {
    @Environment(SessionStore.self) private var sessions
    @Query(sort: \Server.timestamp) private var masters: [Server]

    var target: ConsoleTarget?

    var body: some View {
        content
            .frame(minWidth: 520, minHeight: 300)
            .keepsSessionsInSync()
    }

    @ViewBuilder
    private var content: some View {
        if let target, let session = sessions.session(for: target.masterID) {
            if session.instanceIDs.contains(target.instanceID) || !session.hasLoadedInstances {
                InstanceLogView(session: session, instanceID: target.instanceID)
            } else {
                ContentUnavailableView("Instance Removed", systemImage: "trash", description: Text("This instance no longer exists on \(session.displayName)."))
            }
        } else if let target, masters.contains(where: { $0.id == target.masterID }) {
            // Restored before the sessions were created.
            ProgressView()
        } else {
            ContentUnavailableView("Console Unavailable", systemImage: "terminal", description: Text("The master of this console was removed."))
        }
    }
}
#endif
