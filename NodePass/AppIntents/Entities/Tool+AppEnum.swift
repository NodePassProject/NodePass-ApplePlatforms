//
//  Tool+AppEnum.swift
//  NodePass
//
//  The sidebar tools as a value Shortcuts and Siri can name ("Open TCP Ping in NodePass").
//

import AppIntents

extension Tool: AppEnum {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Tool")

    static let caseDisplayRepresentations: [Tool: DisplayRepresentation] = [
        .tcping: DisplayRepresentation(
            title: "TCP Ping",
            subtitle: "Measure TCP reachability from a master",
            image: .init(systemName: "dot.radiowaves.left.and.right")
        ),
        .urlInspector: DisplayRepresentation(
            title: "URL Inspector",
            subtitle: "Explain and validate instance URLs",
            image: .init(systemName: "text.magnifyingglass")
        ),
        .apiConsole: DisplayRepresentation(
            title: "API Console",
            subtitle: "Send raw requests to a master",
            image: .init(systemName: "terminal")
        ),
    ]
}
