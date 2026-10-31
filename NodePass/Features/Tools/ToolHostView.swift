//
//  ToolHostView.swift
//  NodePass
//

import SwiftUI

struct ToolHostView: View {
    var tool: Tool
    var masters: [Server]

    var body: some View {
        switch tool {
        case .tcping:
            TCPingToolView(masters: masters)
        case .urlInspector:
            URLInspectorView()
        case .apiConsole:
            APIConsoleView(masters: masters)
        }
    }
}
