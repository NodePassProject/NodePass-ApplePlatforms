//
//  MenuBarStatusView.swift
//  NodePass
//
//  The macOS menu bar item: fleet health at a glance, one row per master, and a way back into
//  the app. Sessions keep streaming while it is shown, so it stays current without a window.
//

#if os(macOS)
import SwiftUI
import SwiftData
import AppKit

/// Overall state of every enabled master.
enum FleetHealth {
    /// No master is enabled.
    case idle
    case nominal
    /// A master is offline or an instance reports an error.
    case attention

    var symbolName: String {
        switch self {
        case .idle, .nominal: "point.3.connected.trianglepath.dotted"
        case .attention: "exclamationmark.triangle"
        }
    }
}

extension SessionStore {
    var health: FleetHealth {
        let enabled = sessions.values.filter(\.snapshot.isEnabled)
        guard !enabled.isEmpty else { return .idle }
        let needsAttention = enabled.contains { session in
            if case .offline = session.connection { return true }
            return session.errorCount > 0
        }
        return needsAttention ? .attention : .nominal
    }
}

struct MenuBarStatusLabel: View {
    var sessions: SessionStore

    var body: some View {
        Image(systemName: sessions.health.symbolName)
            .accessibilityLabel("NodePass")
    }
}

struct MenuBarStatusView: View {
    @Environment(SessionStore.self) private var sessions
    @Environment(\.openWindow) private var openWindow
    @Query(sort: \Server.timestamp) private var masters: [Server]

    private var enabledMasters: [Server] { masters.filter(\.isEnabled) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            Divider()
            if enabledMasters.isEmpty {
                Text(masters.isEmpty ? "No masters yet." : "Every master is disabled.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
            } else {
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(enabledMasters) { master in
                            MenuBarMasterRow(master: master, session: sessions.session(for: master.id)) {
                                show(.master(master.id))
                            }
                        }
                    }
                    .padding(6)
                }
                .frame(maxHeight: 380)
                .fixedSize(horizontal: false, vertical: true)
            }
            Divider()
            footer
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
        }
        .frame(width: 340)
        .keepsSessionsInSync()
    }

    private var header: some View {
        let sessions = enabledMasters.compactMap { self.sessions.session(for: $0.id) }
        let reachable = sessions.filter { $0.connection.isReachable }.count
        let running = sessions.reduce(0) { $0 + $1.runningCount }
        let errors = sessions.reduce(0) { $0 + $1.errorCount }
        return HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("NodePass")
                    .font(.headline)
                Text("\(reachable) of \(sessions.count) masters reachable · \(running) running")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if errors > 0 {
                Pill(text: errors == 1 ? "1 error" : "\(errors) errors", tint: .red, systemImage: "exclamationmark.triangle.fill")
            }
        }
    }

    private var footer: some View {
        HStack {
            Button("Open NodePass") { show(nil) }
            Spacer()
            SettingsLink {
                Label("Settings…", systemImage: "gearshape")
            }
            .labelStyle(.iconOnly)
            .help("Settings")
            Button("Quit NodePass", systemImage: "power") { NSApplication.shared.terminate(nil) }
                .labelStyle(.iconOnly)
                .help("Quit NodePass")
        }
        .buttonStyle(.borderless)
    }

    /// Brings the app forward on a master, or on any main window.
    private func show(_ item: SidebarItem?) {
        NSApplication.shared.activate()
        if let item {
            // Focuses the window already showing this master, or opens one for it.
            openWindow(value: item)
        } else if !NSApplication.shared.windows.contains(where: { $0.isVisible && $0.identifier?.rawValue.hasPrefix(SceneID.main) == true }) {
            openWindow(id: SceneID.main)
        }
    }
}

private struct MenuBarMasterRow: View {
    var master: Server
    var session: MasterSession?
    var action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Circle()
                    .fill(session?.connection.tint ?? .gray)
                    .frame(width: 8, height: 8)
                VStack(alignment: .leading, spacing: 1) {
                    Text(master.displayName)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 6)
                if let session, session.hasLoadedInstances {
                    VStack(alignment: .trailing, spacing: 1) {
                        HStack(spacing: 4) {
                            if session.errorCount > 0 {
                                Text("\(session.errorCount)")
                                    .foregroundStyle(.red)
                            }
                            Text("\(session.runningCount)/\(session.counts.total)")
                        }
                        .font(.callout.monospacedDigit())
                        let rate = session.aggregateRate
                        if rate.received + rate.transmitted > 0 {
                            Text(Format.bitRate(bytesPerSecond: rate.received + rate.transmitted))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .contentShape(.rect)
            .background(isHovered ? AnyShapeStyle(.fill.tertiary) : AnyShapeStyle(.clear), in: .rect(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }

    private var detail: String {
        guard let session else { return master.host ?? master.url }
        switch session.connection {
        case .offline(let reason): return reason
        case .connecting: return "Connecting…"
        case .idle: return master.host ?? "Idle"
        case .live, .polling:
            if let info = session.info, info.hasSystemMetrics {
                return "CPU \(info.cpuUsage < 0 ? "—" : "\(info.cpuUsage)%") · Mem \(Format.percent(info.memoryRatio)) · \(master.host ?? "")"
            }
            return master.host ?? session.connection.title
        }
    }
}
#endif
