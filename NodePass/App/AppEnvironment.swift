//
//  AppEnvironment.swift
//  NodePass
//
//  Environment shared by the root view of every scene.
//

import SwiftUI
import SwiftData

extension View {
    /// Injects the app-wide services and applies the user's appearance.
    func appEnvironment(settings: AppSettings, sessions: SessionStore, container: ModelContainer) -> some View {
        environment(settings)
            .environment(sessions)
            .modelContainer(container)
            .preferredColorScheme(settings.theme.colorScheme)
    }

    /// Keeps `SessionStore` in step with the persisted masters while this view is on screen.
    ///
    /// Attached to every scene that shows live data, so a restored console window or the menu bar
    /// works even when no main window is open.
    func keepsSessionsInSync() -> some View {
        modifier(SessionSyncModifier())
    }
}

private struct SessionSyncModifier: ViewModifier {
    @Environment(AppSettings.self) private var settings
    @Environment(SessionStore.self) private var sessions
    @Query(sort: \Server.timestamp) private var masters: [Server]

    func body(content: Content) -> some View {
        content.task(id: syncKey) {
            sessions.sync(with: masters, configuration: settings.sessionConfiguration)
        }
    }

    /// Changes whenever a master is added, removed or edited.
    private var syncKey: [String] {
        masters.map { "\($0.id)|\($0.name)|\($0.url)|\($0.key)|\($0.isEnabled)|\($0.flavorRawValue ?? "")|\($0.trustsSelfSignedCertificates)" }
    }
}
