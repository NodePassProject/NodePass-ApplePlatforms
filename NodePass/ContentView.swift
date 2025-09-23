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
        if #available(iOS 18.0, macOS 14.0, *) {
            TabView(selection: Bindable(state).tab) {
                Tab(value: MainTab.services) {
                    NavigationStack(path: Bindable(state).pathServices) {
                        ServiceListView()
                    }
                } label: {
                    Label(MainTab.services.title, systemImage: MainTab.services.systemName)
                }
                
                Tab(value: MainTab.servers) {
                    NavigationSplitView {
                        ServerListView()
                            .navigationSplitViewColumnWidth(min: 350, ideal: 400)
                    } detail: {
                        Text("Select a server to start")
                            .foregroundStyle(.secondary)
                    }
                } label: {
                    Label(MainTab.servers.title, systemImage: MainTab.servers.systemName)
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
                
                NavigationSplitView {
                    ServerListView()
                        .navigationSplitViewColumnWidth(min: 350, ideal: 400)
                } detail: {
                    Text("Select a server to start")
                        .foregroundStyle(.secondary)
                }
                .tag(MainTab.servers)
                .tabItem {
                    Label(MainTab.servers.title, systemImage: MainTab.servers.systemName)
                }
            }
        }
    }
}
