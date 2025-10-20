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
    @State private var serverMetadataUpdateInterval: Double = NPCore.serverMetadataUpdateInterval
    
    var body: some View {
        Form {
            Section {
                Toggle("Advanced Mode", isOn: $isAdvancedModeEnabled)
                    .onChange(of: isAdvancedModeEnabled) {
                        NPCore.userDefaults.set(isAdvancedModeEnabled, forKey: NPCore.Strings.NPAdvancedMode)
                        if isAdvancedModeEnabled {
                            let defaultServerMetadataUpdateInterval = NPCore.Defaults.serverMetadataUpdateInterval
                            NPCore.userDefaults.set(defaultServerMetadataUpdateInterval, forKey: NPCore.Strings.NPServerMetadataUpdateInterval)
                            state.modifyContinuousUpdatingServerMetadataTimerInterval(to: defaultServerMetadataUpdateInterval)
                        }
                    }
            }
            
            if isAdvancedModeEnabled {
                Section {
                    if #available(iOS 26.0, macOS 26.0, *) {
                        Slider(value: $serverMetadataUpdateInterval, in: 2...30) {
                            Text("Server Metadata Updating Rate")
                        } minimumValueLabel: {
                            Image(systemName: "tortoise.fill")
                                .foregroundStyle(.secondary)
                        } maximumValueLabel: {
                            Image(systemName: "hare.fill")
                                .foregroundStyle(.secondary)
                        } ticks: {
                            SliderTick(5)
                            SliderTick(10)
                            SliderTick(15)
                        } onEditingChanged: { editing in
                            if !editing {
                                NPCore.userDefaults.set(serverMetadataUpdateInterval, forKey: NPCore.Strings.NPServerMetadataUpdateInterval)
                                state.modifyContinuousUpdatingServerMetadataTimerInterval(to: serverMetadataUpdateInterval)
                            }
                        }
                    }
                    else {
                        Slider(value: $serverMetadataUpdateInterval, in: 2...30, step: 0.5) {
                            Text("Server Metadata Updating Rate")
                        } minimumValueLabel: {
                            Image(systemName: "tortoise")
                        } maximumValueLabel: {
                            Image(systemName: "hare")
                        } onEditingChanged: { editing in
                            if !editing {
                                state.modifyContinuousUpdatingServerMetadataTimerInterval(to: serverMetadataUpdateInterval)
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
