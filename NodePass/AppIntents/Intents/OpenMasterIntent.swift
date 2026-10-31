//
//  OpenMasterIntent.swift
//  NodePass
//
//  Shows a master. Also what Spotlight runs when a master from the index is chosen.
//

import AppIntents

struct OpenMasterIntent: nonisolated OpenIntent {
    nonisolated static let title: LocalizedStringResource = "Open Master"
    nonisolated static let description = IntentDescription("Shows a master and its instances.", categoryName: "Masters")

    @Parameter(title: "Master", requestValueDialog: "Which master?")
    var target: MasterEntity

    nonisolated init() {}

    init(target: MasterEntity) {
        self.target = target
    }

    // On iOS the targeted scene handles this through `onAppIntentExecution` (see `RootView`).
    #if os(macOS)
    @Dependency private var navigator: IntentNavigator

    @MainActor
    func perform() async throws -> some IntentResult {
        navigator.show(master: target.id)
        return .result()
    }
    #endif
}

#if os(iOS)
extension OpenMasterIntent: nonisolated TargetContentProvidingIntent {}
#endif

extension OpenMasterIntent: nonisolated PredictableIntent {
    nonisolated static var predictionConfiguration: some IntentPredictionConfiguration {
        IntentPrediction(parameters: \.$target) { master in
            DisplayRepresentation(title: "Open \(master.name)", image: master.displayRepresentation.image)
        }
    }
}
