//
//  ContentView.swift
//  NodePass
//
//  Created by Junhui Lou on 6/28/25.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            Tab("Services", systemImage: "arrow.left.and.right.circle") {
                NavigationStack {
                    ServiceListView()
                }
            }
            
            Tab("Servers", systemImage: "apple.terminal") {
                NavigationStack {
                    ServerListView()
                }
            }
        }
    }
}
