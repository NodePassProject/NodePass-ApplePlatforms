//
//  OpenInstanceIntent.swift
//  NodePass
//
//  Shows an instance's detail. Also what Spotlight runs when an instance from the index is chosen.
//

import AppIntents

struct OpenInstanceIntent: nonisolated OpenIntent {
    nonisolated static let title: LocalizedStringResource = "Open Instance"
    nonisolated static let description = IntentDescription("Shows an instance with its controls, metrics and logs.", categoryName: "Instances")

    @Parameter(title: "Instance", requestValueDialog: "Which instance?")
    var target: InstanceEntity

    nonisolated init() {}

    init(target: InstanceEntity) {
        self.target = target
    }

    // On iOS the targeted scene handles this through `onAppIntentExecution` (see `RootView`).
    // macOS and watchOS have no such hook; each app provides an `IntentNavigator` instead.
    #if os(macOS) || os(watchOS)
    @Dependency private var navigator: IntentNavigator

    @MainActor
    func perform() async throws -> some IntentResult {
        navigator.show(instance: target.id.instanceID, on: target.id.masterID)
        return .result()
    }
    #endif
}

#if os(iOS)
extension OpenInstanceIntent: nonisolated TargetContentProvidingIntent {}
#endif
