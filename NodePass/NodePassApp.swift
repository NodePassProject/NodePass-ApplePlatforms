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
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(for: [
                    Service.self,
                    Server.self
                ])
        }
    }
}
