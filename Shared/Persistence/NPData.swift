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

        let hasAppGroup = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: NPCore.appGroupIdentifier) != nil
        var attempts: [ModelConfiguration] = []
        if hasAppGroup {
            attempts.append(ModelConfiguration(schema: schema, isStoredInMemoryOnly: false,
                                               groupContainer: .identifier(NPCore.appGroupIdentifier),
                                               cloudKitDatabase: .automatic))
            attempts.append(ModelConfiguration(schema: schema, isStoredInMemoryOnly: false,
                                               groupContainer: .identifier(NPCore.appGroupIdentifier),
                                               cloudKitDatabase: .none))
        }
        attempts.append(ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, cloudKitDatabase: .none))

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
}
