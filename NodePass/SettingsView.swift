//
//  SettingsView.swift
//  NodePass
//
//  Created by Junhui Lou on 10/19/25.
//

import SwiftUI

struct SettingsView: View {
    @State private var isAdvancedModeEnabled: Bool = NPCore.isAdvancedModeEnabled
    
    var body: some View {
        Form {
            Toggle("Advanced Mode", isOn: $isAdvancedModeEnabled)
                .onChange(of: isAdvancedModeEnabled) {
                    NPCore.userDefaults.set(isAdvancedModeEnabled, forKey: NPCore.Strings.NPAdvancedMode)
                }
        }
        .navigationTitle("Settings")
    }
}
