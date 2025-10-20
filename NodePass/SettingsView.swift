//
//  SettingsView.swift
//  NodePass
//
//  Created by Junhui Lou on 10/19/25.
//

import SwiftUI

struct SettingsView: View {
    @Environment(NPState.self) var state
    
    @State private var isAdvancedModeEnabled: Bool = NPCore.isAdvancedModeEnabled
    @State private var serverMetadataUpdatingRate: Double = NPCore.serverMetadataUpdatingRate
    
    var body: some View {
        Form {
            Section {
                Toggle("Advanced Mode", isOn: $isAdvancedModeEnabled)
                    .onChange(of: isAdvancedModeEnabled) {
                        NPCore.userDefaults.set(isAdvancedModeEnabled, forKey: NPCore.Strings.NPAdvancedMode)
                        if isAdvancedModeEnabled {
                            let defaultServerMetadataUpdatingRate = NPCore.Defaults.serverMetadataUpdatingRate
                            NPCore.userDefaults.set(defaultServerMetadataUpdatingRate, forKey: NPCore.Strings.NPServerMetadataUpdatingRate)
                            state.modifyContinuousUpdatingServerMetadataTimerInterval(to: 1 / defaultServerMetadataUpdatingRate)
                        }
                    }
            }
            
            if isAdvancedModeEnabled {
                Section {
                    if #available(iOS 26.0, macOS 26.0, *) {
                        Slider(value: $serverMetadataUpdatingRate, in: 0.05...0.2) {
                            Text("Server Metadata Updating Rate")
                        } minimumValueLabel: {
                            Image(systemName: "tortoise.fill")
                                .foregroundStyle(.secondary)
                        } maximumValueLabel: {
                            Image(systemName: "hare.fill")
                                .foregroundStyle(.secondary)
                        } ticks: {
                            SliderTick(0.1)
                        } onEditingChanged: { editing in
                            if !editing {
                                NPCore.userDefaults.set(serverMetadataUpdatingRate, forKey: NPCore.Strings.NPServerMetadataUpdatingRate)
                                state.modifyContinuousUpdatingServerMetadataTimerInterval(to: 1 / serverMetadataUpdatingRate)
                            }
                        }
                    }
                    else {
                        Slider(value: $serverMetadataUpdatingRate, in: 0.05...0.2) {
                            Text("Server Metadata Updating Rate")
                        } minimumValueLabel: {
                            Image(systemName: "tortoise")
                        } maximumValueLabel: {
                            Image(systemName: "hare")
                        } onEditingChanged: { editing in
                            if !editing {
                                NPCore.userDefaults.set(serverMetadataUpdatingRate, forKey: NPCore.Strings.NPServerMetadataUpdatingRate)
                                state.modifyContinuousUpdatingServerMetadataTimerInterval(to: 1 / serverMetadataUpdatingRate)
                            }
                        }
                    }
                } header: {
                    Text("Server Metadata Updating Rate")
                } footer: {
                    Text("Adjust the updating rate of server metadata.")
                }
            }
        }
        .navigationTitle("Settings")
    }
}
