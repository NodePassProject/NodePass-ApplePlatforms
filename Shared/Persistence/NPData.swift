//
//  NPData.swift
//  NodePass
//
//  SwiftData container shared by the app and its extensions through the App Group.
//

import Foundation
import SwiftData

nonisolated enum NPData {
    static let schema = Schema([Server.self])

    /// Creates the shared container.
    ///
    /// Preferred: App Group store mirrored to CloudKit so masters follow the user across devices.
    /// Falls back to an App Group store without CloudKit, then to a plain local store, so a build
    /// without the matching entitlements (CI, unsigned simulator runs) still launches.
    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        if inMemory {
            return try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        }

        #if DEBUG
        // `NodePass -NPStoreDirectory <dir>` keeps a run's masters apart from the real store, for
        // screenshots and experiments on a Mac where the app is in daily use. Never synced.
        if let directory = UserDefaults.standard.string(forKey: "NPStoreDirectory") {
            let directoryURL = URL(filePath: directory, directoryHint: .isDirectory)
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            let configuration = ModelConfiguration(schema: schema, url: directoryURL.appending(path: "NodePass.store"), cloudKitDatabase: .none)
            return try ModelContainer(for: schema, configurations: [configuration])
        }
        #endif

        var attempts: [ModelConfiguration] = []
        if NPCore.isAppGroupAvailable {
            attempts.append(ModelConfiguration(schema: schema, isStoredInMemoryOnly: false,
                                               groupContainer: .identifier(NPCore.appGroupIdentifier),
                                               cloudKitDatabase: .automatic))
            attempts.append(ModelConfiguration(schema: schema, isStoredInMemoryOnly: false,
                                               groupContainer: .identifier(NPCore.appGroupIdentifier),
                                               cloudKitDatabase: .none))
        }
        attempts.append(ModelConfiguration(schema: schema, url: localStoreURL, cloudKitDatabase: .none))

        var lastError: any Error = CocoaError(.fileNoSuchFile)
        for configuration in attempts {
            do {
                return try ModelContainer(for: schema, configurations: [configuration])
            } catch {
                lastError = error
            }
        }
        throw lastError
    }

    /// Store used without an App Group. It is named explicitly because an unsandboxed macOS build
    /// shares `~/Library/Application Support` with every other app, where SwiftData's default
    /// `default.store` could belong to someone else.
    private static var localStoreURL: URL {
        let directory = URL.applicationSupportDirectory.appending(path: "NodePass", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appending(path: "NodePass.store")
    }
}
