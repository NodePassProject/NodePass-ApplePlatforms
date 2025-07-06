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
    var tab: MainTab = .services
    
    var pathServices: NavigationPath = .init()
    var pathServers: NavigationPath = .init()
}
