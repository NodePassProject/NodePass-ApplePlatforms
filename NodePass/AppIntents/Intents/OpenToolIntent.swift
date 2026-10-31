//
//  OpenToolIntent.swift
//  NodePass
//
//  Shows one of the tools in the sidebar.
//

import AppIntents

struct OpenToolIntent: nonisolated AppIntent {
    nonisolated static let title: LocalizedStringResource = "Open Tool"
    nonisolated static let description = IntentDescription("Shows TCP Ping, the URL Inspector or the API Console.", categoryName: "Tools")
    nonisolated static let supportedModes: IntentModes = .foreground

    nonisolated static var parameterSummary: some ParameterSummary {
        Summary("Open \(\.$tool)")
    }

    @Parameter(title: "Tool", requestValueDialog: "Which tool?")
    var tool: Tool

    nonisolated init() {}

    init(tool: Tool) {
        self.tool = tool
    }

    #if os(macOS)
    @Dependency private var navigator: IntentNavigator

    @MainActor
    func perform() async throws -> some IntentResult {
        navigator.show(tool: tool)
        return .result()
    }
    #endif
}

#if os(iOS)
extension OpenToolIntent: nonisolated TargetContentProvidingIntent {}
#endif
