//
//  NPState.swift
//  NodePass
//
//  Created by Junhui Lou on 6/28/25.
//

import SwiftUI
import Observation

@Observable
class NPState {
    // Tab
    var tab: MainTab = .services
    
    // Navigation
    var pathServices: NavigationPath = .init()
    var pathServers: NavigationPath = .init()
    
    // Edit Server Sheet
    var isShowEditServerSheet: Bool = false
    var editServerSheetMode: EditServerSheetMode = .adding
    var editServerSheetServer: Server?
}
