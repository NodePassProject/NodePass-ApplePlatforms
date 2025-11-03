//
//  NodePassApp.swift
//  NodePass
//
//  Created by Junhui Lou on 6/28/25.
//

import SwiftUI
import SwiftData
import RevenueCat

@main
struct NodePassApp: App {
    let state: NPState = .init()
    
    init() {
        NPCore.registerUserDefaults()
        guard let revenueCatAPIKey = Bundle.main.object(forInfoDictionaryKey: "RevenueCatAPIKey") as? String else {
            fatalError("RevenueCatAPIKey not found in Info.plist")
        }
        Purchases.configure(withAPIKey: revenueCatAPIKey)
        state.startContinuousUpdatingServerMetadatas()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(state)
                .modelContainer(for: [
                    Service.self,
                    Server.self
                ])
                .onOpenURL { url in
                    handleIncomingURL(url)
                }
        }
    }
    
    private func handleIncomingURL(_ url: URL) {
        guard url.scheme == "np" else {
#if DEBUG
            print("Incoming Link Error - Invalid Scheme")
#endif
            return
        }
        
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
#if DEBUG
            print("Incoming Link Error - Invalid URL")
#endif
            return
        }
        
        guard let action = components.host else {
#if DEBUG
            print("Incoming Link Error - No action")
#endif
            return
        }
        
        switch(action) {
        case "master":
            guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
                  let queryItems = components.queryItems else {
#if DEBUG
                print("Failed to parse URL components")
#endif
                return
            }
            
            var result = [String: String]()
            
            for item in queryItems {
                if let value = item.value,
                   let decodedData = Data(base64Encoded: value),
                   let decodedString = String(data: decodedData, encoding: .utf8) {
                    result[item.name] = decodedString
                }
            }
            
            state.tab = .servers
            state.editServerSheetMode = .adding
            state.editServerSheetServer = Server(name: "", url: result["url"] ?? "", key: result["key"] ?? "")
            state.isShowEditServerSheet = true
            
            return
        case "server":
            state.tab = .servers
            return
        default:
#if DEBUG
            print("Incoming Link Error - Unknown action")
#endif
            return
        }
    }
}
