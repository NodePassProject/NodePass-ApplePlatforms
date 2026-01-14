//
//  SettingsView.swift
//  NodePass
//
//  Created by Junhui Lou on 10/19/25.
//

import SwiftUI
import RevenueCat
import RevenueCatUI

struct SettingsView: View {
    @Environment(NPState.self) var state
    
    @State private var isAdvancedModeEnabled: Bool = NPCore.isAdvancedModeEnabled
    @State private var serverMetadataUpdatingRate: Double = NPCore.serverMetadataUpdatingRate
    @State private var selectedTheme: NPCore.AppTheme = NPCore.appTheme
    
    @State private var isUserSupporter: Bool = false
    
    var body: some View {
        Form {
            if isUserSupporter {
                Section {
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.accent)
                        Text("NodePass Supporter")
                    }
                }
            }
            
            Section {
                Picker(String(localized: "Theme"), selection: $selectedTheme) {
                    ForEach(NPCore.AppTheme.allCases, id: \.self) { theme in
                        Text(theme.displayName).tag(theme)
                    }
                }
                .onChange(of: selectedTheme) {
                    NPCore.appTheme = selectedTheme
                }
            }
            
            Section {
                advancedModeButton
            }
            
            if isAdvancedModeEnabled {
                Section {
                    serverMetadataUpdatingRateSlider
                } header: {
                    Text("Server Metadata Updating Rate")
                } footer: {
                    Text("Adjust the updating rate of server metadata.")
                }
            }
            
            Section {
                NavigationLink("Support Us") {
                    PaywallView()
                }
            }
        }
        .navigationTitle("Settings")
        .onAppear {
            Purchases.shared.getCustomerInfo { (customerInfo, _) in
                if customerInfo?.nonSubscriptions.count != 0 {
                    isUserSupporter = true
                }
            }
        }
    }
    
    private var advancedModeButton: some View {
        Toggle("Advanced Mode", isOn: $isAdvancedModeEnabled)
            .onChange(of: isAdvancedModeEnabled) {
                NPCore.userDefaults.set(isAdvancedModeEnabled, forKey: NPCore.Strings.NPAdvancedMode)
                if !isAdvancedModeEnabled {
                    // Restore server metadata updating rate to default
                    let defaultServerMetadataUpdatingRate = NPCore.Defaults.serverMetadataUpdatingRate
                    
                    serverMetadataUpdatingRate = defaultServerMetadataUpdatingRate
                    state.modifyContinuousUpdatingServerMetadataTimerInterval(to: 1 / defaultServerMetadataUpdatingRate)
                    
                    NPCore.userDefaults.set(defaultServerMetadataUpdatingRate, forKey: NPCore.Strings.NPServerMetadataUpdatingRate)
                }
            }
    }
    
    private var serverMetadataUpdatingRateSlider: some View {
        Slider(value: $serverMetadataUpdatingRate, in: 0.05...0.2) {
            Text("Server Metadata Updating Rate")
        } minimumValueLabel: {
            Image(systemName: "tortoise")
                .foregroundStyle(.secondary)
        } maximumValueLabel: {
            Image(systemName: "hare")
                .foregroundStyle(.secondary)
        } onEditingChanged: { editing in
            if !editing {
                updateServerMetadataUpdatingRate()
            }
        }
    }
    
    private func updateServerMetadataUpdatingRate() {
        state.modifyContinuousUpdatingServerMetadataTimerInterval(to: 1 / serverMetadataUpdatingRate)
        
        NPCore.userDefaults.set(serverMetadataUpdatingRate, forKey: NPCore.Strings.NPServerMetadataUpdatingRate)
    }
}
