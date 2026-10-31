//
//  SettingsView.swift
//  NodePass
//
//  The iOS settings sheet. macOS uses `SettingsWindow`.
//

#if os(iOS)
import SwiftUI

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                AppearanceSettingsSection(settings: settings)
                LiveDataSettingsSection(settings: settings)
                LogSettingsSection(settings: settings)
                BehaviorSettingsSection(settings: settings)
                PrivacySettingsSection(settings: settings)
                SupportSettingsSection()
                AboutSettingsSection()
            }
            .formStyle(.grouped)
            .navigationTitle("Settings")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", systemImage: "checkmark", role: .confirm) { dismiss() }
                }
            }
        }
    }
}
#endif
