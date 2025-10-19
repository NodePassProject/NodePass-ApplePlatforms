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
    case settings = "settings"
    
    var systemName: String {
        switch self {
        case .services: "arrow.left.and.right.circle"
        case .servers: "apple.terminal"
        case .settings: "gear.circle.fill"
        }
    }
    
    var title: String {
        switch self {
        case .services: String(localized: "Services")
        case .servers: String(localized: "Servers")
        case .settings: String(localized: "Settings")
        }
    }
}

struct ContentView: View {
    @Environment(NPState.self) var state
    
    var body: some View {
        if #available(iOS 18.0, macOS 15.0, *) {
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
                
                Tab(value: MainTab.settings) {
                    NavigationStack {
                        SettingsView()
                    }
                } label: {
                    Label(MainTab.settings.title, systemImage: MainTab.settings.systemName)
                }
            }
            .tabViewStyle(.sidebarAdaptable)
        }
        else {
            TabView(selection: Bindable(state).tab) {
                NavigationStack(path: Bindable(state).pathServices) {
                    ServiceListView()
                }
                .tag(MainTab.services)
                .tabItem {
                    Label(MainTab.services.title, systemImage: MainTab.services.systemName)
                }
                
                NavigationStack(path: Bindable(state).pathServers) {
                    ServerListView()
                }
                .tag(MainTab.servers)
                .tabItem {
                    Label(MainTab.servers.title, systemImage: MainTab.servers.systemName)
                }
                
                NavigationStack {
                    SettingsView()
                }
                .tag(MainTab.settings)
                .tabItem {
                    Label(MainTab.settings.title, systemImage: MainTab.settings.systemName)
                }
            }
        }
    }
}
