//
//  ServerDetailConfigurationIntent.swift
//  NodePass
//
//  Created by Junhui Lou on 9/19/25.
//

import WidgetKit
import AppIntents

struct ServerDetailConfigurationIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Configure Widget"
    static let description = IntentDescription("Configure Server Detail Widget")

    @Parameter(title: "Server")
    var server: ServerEntity?
    
    init() {}
    
    init(server: ServerEntity) {
        self.server = server
    }
}
