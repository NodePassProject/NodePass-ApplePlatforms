//
//  MastersView.swift
//  NodePass Watch App
//
//  The root list: every master mirrored from the iPhone, with its live health.
//

import SwiftUI

struct MastersView: View {
    @Environment(SessionStore.self) private var sessions
    @Environment(MasterMirror.self) private var mirror
    @Environment(WatchBridge.self) private var bridge

    private var enabled: [MasterSnapshot] { mirror.snapshots.filter(\.isEnabled) }
    private var disabled: [MasterSnapshot] { mirror.snapshots.filter { !$0.isEnabled } }

    var body: some View {
        Group {
            if mirror.isEmpty {
                NoMastersView()
            } else {
                list
            }
        }
        .navigationTitle("NodePass")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                SyncButton()
            }
        }
    }

    private var list: some View {
        List {
            Section {
                ForEach(enabled) { master in
                    NavigationLink(value: WatchRoute.master(master.id)) {
                        MasterRow(master: master, session: sessions.session(for: master.id))
                    }
                }
            } footer: {
                footer
            }
            if !disabled.isEmpty {
                Section("Disabled on iPhone") {
                    ForEach(disabled) { master in
                        MasterRow(master: master, session: sessions.session(for: master.id))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var footer: some View {
        if let error = bridge.lastRequestError {
            Label(error, systemImage: "exclamationmark.triangle")
                .foregroundStyle(.secondary)
        } else if let date = mirror.receivedAt {
            Text("From iPhone \(Text(date, style: .relative)) ago")
                .foregroundStyle(.tertiary)
        }
    }
}

/// Pulls the masters from the iPhone again. The phone pushes changes itself, so this is for the
/// first sync and for when something looks out of date.
struct SyncButton: View {
    @Environment(WatchBridge.self) private var bridge

    var body: some View {
        Button("Sync from iPhone", systemImage: "iphone.and.arrow.forward") {
            Haptics.click()
            bridge.requestMasters()
        }
        .disabled(bridge.isRequesting || !bridge.isCompanionAppInstalled)
        .symbolEffect(.pulse, options: .repeating, isActive: bridge.isRequesting)
    }
}

private struct MasterRow: View {
    var master: MasterSnapshot
    var session: MasterSession?

    private var health: MasterSession.Health {
        guard master.isEnabled else { return .disabled }
        return session?.health ?? .connecting
    }

    var body: some View {
        HStack(spacing: 8) {
            HealthGlyph(health: health)
                .font(.title3)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(master.name)
                    .font(.headline)
                    .lineLimit(1)
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
    }

    private var detail: String {
        switch health {
        case .disabled:
            return master.host ?? master.url
        case .connecting:
            return "Connecting…"
        case .offline:
            return session?.connectionDetail ?? "Offline"
        case .errors, .online:
            guard let session else { return "" }
            var parts = ["\(session.runningCount) running"]
            if session.errorCount > 0 {
                parts.append(session.errorCount == 1 ? "1 error" : "\(session.errorCount) errors")
            } else if session.stoppedCount > 0 {
                parts.append("\(session.stoppedCount) stopped")
            }
            return parts.joined(separator: " · ")
        }
    }
}

/// What the app shows before any master arrived from the iPhone.
struct NoMastersView: View {
    @Environment(WatchBridge.self) private var bridge

    var body: some View {
        ScrollView {
            ContentUnavailableView {
                Label("No Masters", systemImage: "server.rack")
            } description: {
                Text(description)
            } actions: {
                if bridge.isCompanionAppInstalled {
                    Button {
                        Haptics.click()
                        bridge.requestMasters()
                    } label: {
                        if bridge.isRequesting {
                            ProgressView()
                        } else {
                            Label("Sync from iPhone", systemImage: "iphone.and.arrow.forward")
                        }
                    }
                    .disabled(bridge.isRequesting)
                }
                if let error = bridge.lastRequestError {
                    Text(error)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }

    private var description: String {
        if bridge.isCompanionAppInstalled {
            return "Your masters come from NodePass on iPhone. Add one there and it appears here."
        }
        return "Install NodePass on your iPhone and add a master there. Apple Watch mirrors the iPhone's masters."
    }
}
