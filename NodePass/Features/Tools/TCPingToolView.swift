//
//  TCPingToolView.swift
//  NodePass
//
//  TCP reachability probes executed by a master (`GET /tcping`).
//

import SwiftUI

struct TCPingToolView: View {
    @Environment(SessionStore.self) private var sessions

    var masters: [Server]

    private struct Probe: Identifiable {
        let id = UUID()
        let date: Date
        let masterName: String
        let target: String
        let result: Result<TCPingResult, APIError>
    }

    @State private var selectedMasterID: String?
    @State private var target = ""
    @State private var isRunning = false
    @State private var history: [Probe] = []

    private var enabledMasters: [Server] { masters.filter(\.isEnabled) }

    private var selectedMaster: Server? {
        enabledMasters.first { $0.id == selectedMasterID } ?? enabledMasters.first
    }

    /// Target endpoints seen on the selected master's instances, handy as quick picks.
    private var suggestions: [String] {
        guard let master = selectedMaster, let session = sessions.session(for: master.id) else { return [] }
        var seen = Set<String>()
        var result: [String] = []
        for instance in session.visibleInstances {
            guard let parsed = instance.parsedURL else { continue }
            let candidates = parsed.flavor == .openCtrl ? [parsed.tunnel] : parsed.targets + [parsed.tunnel]
            for endpoint in candidates where endpoint.hasValidPort && !endpoint.isWildcard {
                let text = endpoint.description
                if seen.insert(text).inserted { result.append(text) }
            }
        }
        return Array(result.prefix(8))
    }

    private var canRun: Bool {
        HostPort(parsing: target.trimmingCharacters(in: .whitespaces)).hasValidPort && selectedMaster != nil && !isRunning
    }

    var body: some View {
        Form {
            Section {
                Picker("Run From", selection: Binding(get: { selectedMaster?.id ?? "" }, set: { selectedMasterID = $0 })) {
                    ForEach(enabledMasters) { master in
                        Text(master.displayName).tag(master.id)
                    }
                }
                CodeField(title: "Target", text: $target, prompt: "host:port", input: .url)
                    .submitLabel(.go)
                    .onSubmit { Task { await run() } }
                if !suggestions.isEmpty {
                    ScrollView(.horizontal) {
                        HStack(spacing: 6) {
                            ForEach(suggestions, id: \.self) { suggestion in
                                Button(suggestion) { target = suggestion }
                                    .font(.caption.monospaced())
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                }
            } header: {
                Text("Probe")
            } footer: {
                Text("The master opens a TCP connection to the target and reports the handshake latency. Use it to check what a master can reach, not what this device can reach.")
            }

            Section {
                HStack(spacing: 12) {
                    Button {
                        Task { await run() }
                    } label: {
                        Label("Ping", systemImage: "dot.radiowaves.left.and.right")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canRun)
                    Button {
                        Task { await runFromAll() }
                    } label: {
                        Label("From All Masters", systemImage: "square.stack.3d.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!canRun || enabledMasters.count < 2)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
            }

            if !history.isEmpty {
                Section {
                    ForEach(history) { probe in
                        probeRow(probe)
                    }
                } header: {
                    HStack {
                        Text("Results")
                        Spacer()
                        Button("Clear") { history.removeAll() }
                            .font(.caption)
                            .textCase(nil)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("TCP Ping")
        .inlineNavigationTitle()
        .overlay {
            if enabledMasters.isEmpty {
                ContentUnavailableView("No Enabled Masters", systemImage: "server.rack", description: Text("Add or enable a master to run probes."))
                    .background(.background)
            }
        }
    }

    private func probeRow(_ probe: Probe) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            switch probe.result {
            case .success(let ping) where ping.connected:
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            default:
                Image(systemName: "xmark.octagon.fill").foregroundStyle(.red)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(probe.target)
                    .font(.callout.monospaced())
                HStack(spacing: 6) {
                    Text(probe.masterName)
                    Text("·")
                    Text(probe.date, style: .time)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                if case .success(let ping) = probe.result, let error = ping.error, !ping.connected {
                    Text(error).font(.caption).foregroundStyle(.red)
                }
                if case .failure(let error) = probe.result {
                    Text(error.localizedDescription).font(.caption).foregroundStyle(.red)
                }
            }
            Spacer()
            if case .success(let ping) = probe.result, ping.connected {
                Text("\(ping.latency) ms")
                    .font(.title3.monospacedDigit().weight(.semibold))
                    .foregroundStyle(ping.latency < 100 ? .green : ping.latency < 300 ? .orange : .red)
            }
        }
    }

    private func run() async {
        guard let master = selectedMaster else { return }
        await probe(from: [master])
    }

    private func runFromAll() async {
        await probe(from: enabledMasters)
    }

    private func probe(from masters: [Server]) async {
        let endpoint = HostPort(parsing: target.trimmingCharacters(in: .whitespaces))
        guard endpoint.hasValidPort else { return }
        isRunning = true
        defer { isRunning = false }
        let targetText = endpoint.description
        await withTaskGroup(of: Probe.self) { group in
            for master in masters {
                guard let credentials = master.credentials else { continue }
                let name = master.displayName
                group.addTask {
                    let client = MasterClient(credentials: credentials)
                    do {
                        let result = try await client.tcping(target: targetText)
                        return Probe(date: .now, masterName: name, target: targetText, result: .success(result))
                    } catch {
                        return Probe(date: .now, masterName: name, target: targetText, result: .failure(APIError.wrap(error)))
                    }
                }
            }
            for await probe in group {
                history.insert(probe, at: 0)
            }
        }
        if history.count > 100 { history.removeLast(history.count - 100) }
        Haptics.selection()
    }
}
