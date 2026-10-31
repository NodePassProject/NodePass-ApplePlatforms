//
//  InstanceMetaEditorView.swift
//  NodePass
//
//  Edits the peer reference and tag set of an instance.
//

import SwiftUI

struct InstanceMetaEditorView: View {
    @Environment(\.dismiss) private var dismiss

    var session: MasterSession
    var instance: Instance

    private struct TagRow: Identifiable {
        let id = UUID()
        var key: String
        var value: String
    }

    @State private var peerSID = ""
    @State private var peerType = ""
    @State private var peerAlias = ""
    @State private var tags: [TagRow] = []
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var duplicateKeys: Set<String> {
        var seen = Set<String>(), duplicates = Set<String>()
        for row in tags where !row.key.isEmpty {
            if !seen.insert(row.key).inserted { duplicates.insert(row.key) }
        }
        return duplicates
    }

    private var tooLong: Bool {
        tags.contains { $0.key.count > NPCore.maxValueLength || $0.value.count > NPCore.maxValueLength }
            || [peerSID, peerType, peerAlias].contains { $0.count > NPCore.maxValueLength }
    }

    private var canSave: Bool { duplicateKeys.isEmpty && !tooLong && !isSaving }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    CodeField(title: "Peer ID", text: $peerSID, prompt: "Instance or service ID")
                    CodeField(title: "Peer Type", text: $peerType, prompt: "e.g. server, client, 2")
                    TextField("Peer Alias", text: $peerAlias, prompt: Text("Display name of the counterpart"))
                } header: {
                    Text("Peer")
                } footer: {
                    Text("Optional reference to the instance on the other end of the tunnel. Purely informational; the master does not keep both sides in sync.")
                }

                Section {
                    ForEach($tags) { $row in
                        HStack(spacing: 8) {
                            CodeField(title: "Key", text: $row.key, prompt: "key")
                                .labelsHidden()
                                .frame(maxWidth: .infinity)
                            Text("=")
                                .foregroundStyle(.tertiary)
                            CodeField(title: "Value", text: $row.value, prompt: "value")
                                .labelsHidden()
                                .frame(maxWidth: .infinity)
                            #if os(macOS)
                            RemoveRowButton(title: "Remove Tag") { withAnimation { tags.removeAll { $0.id == row.id } } }
                            #endif
                        }
                        .listRowBackground(duplicateKeys.contains(row.key) ? Color.red.opacity(0.08) : nil)
                    }
                    .onDelete { tags.remove(atOffsets: $0) }
                    Button("Add Tag", systemImage: "plus.circle.fill") {
                        withAnimation { tags.append(TagRow(key: "", value: "")) }
                    }
                } header: {
                    Text("Tags")
                } footer: {
                    if !duplicateKeys.isEmpty {
                        Text("Duplicate keys: \(duplicateKeys.sorted().joined(separator: ", "))")
                            .foregroundStyle(.red)
                    } else if tooLong {
                        Text("Keys and values are limited to \(NPCore.maxValueLength) characters.")
                            .foregroundStyle(.red)
                    } else {
                        Text("Saving replaces the whole tag set on the master.")
                    }
                }

                if let errorMessage {
                    Section { InlineMessage(text: errorMessage, style: .error) }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Metadata")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", systemImage: "checkmark", role: .confirm) { Task { await save() } }
                        .disabled(!canSave)
                }
            }
            .onAppear {
                peerSID = instance.meta.peer.sid
                peerType = instance.meta.peer.type
                peerAlias = instance.meta.peer.alias
                tags = instance.meta.sortedTags.map { TagRow(key: $0.key, value: $0.value) }
            }
        }
        .sheetFrame(width: 520, height: 560)
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        var tagMap: [String: String] = [:]
        for row in tags {
            let key = row.key.trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty else { continue }
            tagMap[key] = row.value.trimmingCharacters(in: .whitespaces)
        }
        let peer = Instance.Peer(
            sid: peerSID.trimmingCharacters(in: .whitespaces),
            type: peerType.trimmingCharacters(in: .whitespaces),
            alias: peerAlias.trimmingCharacters(in: .whitespaces))
        do {
            _ = try await session.patch(InstancePatch(meta: .init(peer: peer, tags: tagMap)), for: instance.id)
            Haptics.success()
            dismiss()
        } catch {
            errorMessage = APIError.wrap(error).localizedDescription
        }
    }
}
