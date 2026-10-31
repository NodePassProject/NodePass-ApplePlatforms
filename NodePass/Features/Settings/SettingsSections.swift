//
//  SettingsSections.swift
//  NodePass
//
//  Form sections shared by the iOS settings sheet and the macOS Settings window.
//

import SwiftUI
import RevenueCat
import RevenueCatUI

struct AppearanceSettingsSection: View {
    @Bindable var settings: AppSettings

    var body: some View {
        Section("Appearance") {
            Picker("Theme", selection: $settings.theme) {
                ForEach(AppTheme.allCases) { theme in
                    Text(theme.title).tag(theme)
                }
            }
            #if os(iOS)
            // The macOS table has its own column and row layout.
            Picker("Instance Layout", selection: $settings.instanceLayout) {
                ForEach(InstanceLayout.allCases) { layout in
                    Label(layout.title, systemImage: layout.symbolName).tag(layout)
                }
            }
            Picker("Instance Rows", selection: $settings.instanceDensity) {
                ForEach(InstanceDensity.allCases) { density in
                    Text(density.title).tag(density)
                }
            }
            Toggle("Show Instance IDs", isOn: $settings.showInstanceIdentifiers)
            #endif
        }
    }
}

struct LiveDataSettingsSection: View {
    @Bindable var settings: AppSettings

    var body: some View {
        Section {
            Toggle("Live Events (SSE)", isOn: $settings.liveEventsEnabled)
            LabeledContent("Instance Polling") {
                Text("\(Int(settings.instancePollInterval)) s")
                    .monospacedDigit()
            }
            Slider(value: $settings.instancePollInterval, in: 3...60, step: 1)
            LabeledContent("Host Metrics Refresh") {
                Text("\(Int(settings.infoRefreshInterval)) s")
                    .monospacedDigit()
            }
            Slider(value: $settings.infoRefreshInterval, in: 2...60, step: 1)
        } header: {
            Text("Live Data")
        } footer: {
            Text("Instances stream through Server-Sent Events. Polling is used as a fallback when the stream is unavailable.")
        }
    }
}

struct LogSettingsSection: View {
    @Bindable var settings: AppSettings

    var body: some View {
        Section {
            Picker("Log Lines per Instance", selection: $settings.logBufferSize) {
                ForEach([200, 500, 1000, 2000, 5000], id: \.self) { size in
                    Text("\(size)").tag(size)
                }
            }
        } header: {
            Text("Logs")
        } footer: {
            Text("Older lines are discarded once the buffer is full.")
        }
    }
}

struct BehaviorSettingsSection: View {
    @Bindable var settings: AppSettings

    var body: some View {
        Section("Behavior") {
            Toggle("Confirm Disruptive Actions", isOn: $settings.confirmDestructiveActions)
            #if os(iOS)
            Toggle("Haptic Feedback", isOn: $settings.hapticsEnabled)
            #endif
        }
    }
}

struct PrivacySettingsSection: View {
    @Bindable var settings: AppSettings

    var body: some View {
        Section {
            Toggle("Share Anonymous Usage Data", isOn: $settings.analyticsEnabled)
        } header: {
            Text("Privacy")
        } footer: {
            Text("Anonymous usage signals via TelemetryDeck help prioritize work. Takes effect at next launch. No master URLs, keys or instance data are ever sent.")
        }
    }
}

struct SupportSettingsSection: View {
    @State private var isSupporter = false
    @State private var isPresentingPaywall = false

    var body: some View {
        Section {
            if isSupporter {
                Label("Thank you for supporting NodePass", systemImage: "heart.fill")
                    .foregroundStyle(.pink)
            }
            Button {
                isPresentingPaywall = true
            } label: {
                Label("Support Development", systemImage: "star")
            }
        } header: {
            Text("Support")
        }
        .sheet(isPresented: $isPresentingPaywall) {
            PaywallView()
                .sheetFrame(width: 520, height: 680)
        }
        .task {
            guard Purchases.isConfigured else { return }
            if let info = try? await Purchases.shared.customerInfo() {
                isSupporter = !info.nonSubscriptions.isEmpty || !info.entitlements.active.isEmpty
            }
        }
    }
}

struct AboutSettingsSection: View {
    private var version: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return "\(short) (\(build))"
    }

    var body: some View {
        Section("About") {
            LabeledContent("Version", value: version)
            ForEach(ExternalLink.allCases) { link in
                Link(destination: link.url) {
                    Label(link.title, systemImage: link.symbolName)
                }
            }
        }
    }
}

/// Documentation and project pages, shared by Settings and the macOS Help menu.
enum ExternalLink: String, CaseIterable, Identifiable {
    case sourceCode
    case nodePassAPI
    case nowhereConfiguration

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sourceCode: "Source Code"
        case .nodePassAPI: "NodePass API Reference"
        case .nowhereConfiguration: "Nowhere Configuration"
        }
    }

    var symbolName: String {
        switch self {
        case .sourceCode: "chevron.left.forwardslash.chevron.right"
        case .nodePassAPI, .nowhereConfiguration: "book"
        }
    }

    var url: URL {
        switch self {
        case .sourceCode: URL(string: "https://github.com/NodePassProject/NodePass-ApplePlatforms")!
        case .nodePassAPI: URL(string: "https://github.com/NodePassProject/nodepass/blob/main/docs/api.md")!
        case .nowhereConfiguration: URL(string: "https://github.com/NodePassProject/Nowhere/blob/main/docs/configuration.md")!
        }
    }
}
