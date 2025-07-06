//
//  ContentView.swift
//  NodePass
//
//  Created by Junhui Lou on 6/28/25.
//

import SwiftUI

enum MainTab: String, CaseIterable {
    case services = "services"
    case servers = "servers"
    
    var systemName: String {
        switch self {
        case .services: "arrow.left.and.right.circle"
        case .servers: "apple.terminal"
        }
    }
    
    var title: String {
        switch self {
        case .services: String(localized: "Services")
        case .servers: String(localized: "Servers")
        }
    }
}

struct ContentView: View {
    @Environment(NPState.self) var state
    
    var body: some View {
        TabView(selection: Bindable(state).tab) {
            Tab(value: MainTab.services) {
                NavigationStack(path: Bindable(state).pathServices) {
                    ServiceListView()
                }
            } label: {
                Label(MainTab.services.title, systemImage: MainTab.services.systemName)
            }
            
            Tab(value: MainTab.servers) {
                NavigationStack(path: Bindable(state).pathServers) {
                    ServerListView()
                }
            } label: {
                Label(MainTab.servers.title, systemImage: MainTab.servers.systemName)
            }
        }
        .tabViewStyle(.sidebarAdaptable)
    }
}
