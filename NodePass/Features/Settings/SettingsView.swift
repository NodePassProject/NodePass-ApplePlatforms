//
//  SettingsView.swift
//  NodePass
//

import SwiftUI
import RevenueCat
import RevenueCatUI

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    @State private var isSupporter = false
    @State private var isPresentingPaywall = false

    private var version: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return "\(short) (\(build))"
    }

    var body: some View {
        @Bindable var settings = settings
        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker("Theme", selection: $settings.theme) {
                        ForEach(AppTheme.allCases) { theme in
                            Text(theme.title).tag(theme)
                        }
                    }
                    Picker("Instance Rows", selection: $settings.instanceDensity) {
                        ForEach(InstanceDensity.allCases) { density in
                            Text(density.title).tag(density)
                        }
                    }
                    Toggle("Show Instance IDs", isOn: $settings.showInstanceIdentifiers)
                }

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

                Section("Behavior") {
                    Toggle("Confirm Disruptive Actions", isOn: $settings.confirmDestructiveActions)
                    Toggle("Haptic Feedback", isOn: $settings.hapticsEnabled)
                }

                Section {
                    Toggle("Share Anonymous Usage Data", isOn: $settings.analyticsEnabled)
                } header: {
                    Text("Privacy")
                } footer: {
                    Text("Anonymous usage signals via TelemetryDeck help prioritize work. Takes effect at next launch. No master URLs, keys or instance data are ever sent.")
                }

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

                Section("About") {
                    LabeledContent("Version", value: version)
                    Link(destination: URL(string: "https://github.com/NodePassProject/NodePass-ApplePlatforms")!) {
                        Label("Source Code", systemImage: "chevron.left.forwardslash.chevron.right")
                    }
                    Link(destination: URL(string: "https://github.com/NodePassProject/nodepass/blob/main/docs/api.md")!) {
                        Label("NodePass API Reference", systemImage: "book")
                    }
                    Link(destination: URL(string: "https://github.com/NodePassProject/Nowhere/blob/main/docs/configuration.md")!) {
                        Label("Nowhere Configuration", systemImage: "book")
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", role: .confirm) { dismiss() }
                }
            }
            .sheet(isPresented: $isPresentingPaywall) {
                PaywallView()
            }
            .task {
                guard Purchases.isConfigured else { return }
                if let info = try? await Purchases.shared.customerInfo() {
                    isSupporter = !info.nonSubscriptions.isEmpty || !info.entitlements.active.isEmpty
                }
            }
        }
    }
}
