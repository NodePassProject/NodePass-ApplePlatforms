//
//  ServerSentEventParser.swift
//  NodePass
//
//  Incremental parser for the text/event-stream format (WHATWG HTML §9.2).
//

import Foundation

nonisolated struct ServerSentEvent: Hashable, Sendable {
    var event: String?
    var data: String
    var id: String?
    var retry: Int?
}

nonisolated struct ServerSentEventParser: Sendable {
    private var eventName: String?
    private var dataLines: [String] = []
    private var lastEventID: String?
    private var retry: Int?
    private var sawField = false

    init() {}

    /// Feeds one line (without its terminator). Returns a complete event when a blank line closes a block.
    mutating func feed(line rawLine: String) -> ServerSentEvent? {
        var line = Substring(rawLine)
        if line.hasSuffix("\r") { line = line.dropLast() }

        if line.isEmpty {
            defer { reset() }
            guard sawField, !dataLines.isEmpty || eventName != nil else { return nil }
            return ServerSentEvent(event: eventName, data: dataLines.joined(separator: "\n"), id: lastEventID, retry: retry)
        }

        if line.hasPrefix(":") { return nil } // comment / keep-alive

        sawField = true
        let field: Substring
        var value: Substring
        if let colon = line.firstIndex(of: ":") {
            field = line[..<colon]
            value = line[line.index(after: colon)...]
            if value.hasPrefix(" ") { value = value.dropFirst() }
        } else {
            field = line
            value = ""
        }

        switch field {
        case "event": eventName = String(value)
        case "data": dataLines.append(String(value))
        case "id": lastEventID = String(value)
        case "retry": retry = Int(value)
        default: break
        }
        return nil
    }

    private mutating func reset() {
        eventName = nil
        dataLines = []
        sawField = false
        // `id` and `retry` persist across events per the specification.
    }
}
