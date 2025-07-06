//
//  NodePassApp.swift
//  NodePass
//
//  Created by Junhui Lou on 6/28/25.
//

import SwiftUI
import SwiftData

@main
struct NodePassApp: App {
    private var state: NPState = .init()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(state)
                .modelContainer(for: [
                    Service.self,
                    Server.self
                ])
        }
    }
}
