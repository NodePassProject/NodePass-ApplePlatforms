//
//  SettingsWindow.swift
//  NodePass
//
//  The macOS Settings window (⌘,), one tab per area.
//

#if os(macOS)
import SwiftUI
import ServiceManagement

struct SettingsWindow: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        TabView {
            Tab("General", systemImage: "gearshape") {
                pane {
                    AppearanceSettingsSection(settings: settings)
                    MenuBarSettingsSection(settings: settings)
                    BehaviorSettingsSection(settings: settings)
                }
            }
            Tab("Live Data", systemImage: "antenna.radiowaves.left.and.right") {
                pane {
                    LiveDataSettingsSection(settings: settings)
                    LogSettingsSection(settings: settings)
                }
            }
            Tab("Privacy", systemImage: "hand.raised") {
                pane {
                    PrivacySettingsSection(settings: settings)
                }
            }
            Tab("About", systemImage: "info.circle") {
                pane {
                    AboutSettingsSection()
                    SupportSettingsSection()
                }
            }
        }
        .frame(width: 520)
    }

    private func pane(@ViewBuilder content: () -> some View) -> some View {
        Form(content: content)
            .formStyle(.grouped)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct MenuBarSettingsSection: View {
    @Bindable var settings: AppSettings

    @State private var opensAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginItemError: String?

    var body: some View {
        Section {
            Toggle("Show in Menu Bar", isOn: $settings.showsMenuBarExtra)
            Toggle("Open at Login", isOn: Binding(get: { opensAtLogin }, set: updateLoginItem))
            if SMAppService.mainApp.status == .requiresApproval {
                LabeledContent("Login item needs approval") {
                    Button("Open Login Items…") { SMAppService.openSystemSettingsLoginItems() }
                }
            }
            if let loginItemError {
                InlineMessage(text: loginItemError, style: .warning)
            }
        } header: {
            Text("Menu Bar")
        } footer: {
            Text("The menu bar item shows the health of every master and keeps live data flowing after you close the last window.")
        }
    }

    private func updateLoginItem(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            loginItemError = nil
        } catch {
            loginItemError = error.localizedDescription
        }
        opensAtLogin = SMAppService.mainApp.status == .enabled
    }
}
#endif
