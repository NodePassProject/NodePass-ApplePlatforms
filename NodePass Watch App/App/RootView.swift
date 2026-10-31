//
//  RootView.swift
//  NodePass Watch App
//
//  The navigation stack: masters → one master → one instance. Widget taps (`np://` links) and the
//  Open intents land here and set the path.
//

import SwiftUI

struct RootView: View {
    @Environment(IntentNavigator.self) private var navigator

    @State private var path: [WatchRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            MastersView()
                .navigationDestination(for: WatchRoute.self) { route in
                    switch route {
                    case .master(let id):
                        MasterDetailView(masterID: id)
                    case .instance(let masterID, let instanceID):
                        InstanceDetailView(masterID: masterID, instanceID: instanceID)
                    }
                }
        }
        .onOpenURL { url in
            if let route = WatchRoute(deepLink: url) { path = route.path }
        }
        .onChange(of: navigator.pending) { _, pending in
            guard pending != nil, let route = navigator.takePending() else { return }
            path = route.path
        }
        #if DEBUG
        // `xcrun simctl launch <watch> com.argsment.NodePass.watchkitapp -NPOpenRoute "np://master?id=…"`
        // opens a screen in the simulator, which cannot open the app's links itself.
        .onAppear {
            if let link = UserDefaults.standard.string(forKey: "NPOpenRoute"), let url = URL(string: link), let route = WatchRoute(deepLink: url) {
                path = route.path
            }
        }
        #endif
    }
}
