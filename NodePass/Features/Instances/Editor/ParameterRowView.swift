//
//  ParameterRowView.swift
//  NodePass
//
//  One key–value row of the instance editor with a control matched to the parameter's type.
//

import SwiftUI

struct ParameterRowView: View {
    @Binding var row: InstanceEditorModel.ParameterRow
    var spec: ParameterSpec?
    var isApplicable: Bool
    var roleTitle: String
    /// Removes the row. iOS removes rows by swiping instead.
    var onRemove: () -> Void = {}

    private var problem: String? { spec?.validate(row.value) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(spec?.title ?? row.key)
                        .font(.subheadline)
                    Text(row.key)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                }
                .frame(minWidth: 90, alignment: .leading)
                Spacer(minLength: 0)
                valueControl
                    .frame(maxWidth: 260, alignment: .trailing)
                #if os(macOS)
                RemoveRowButton(title: "Remove Parameter", action: onRemove)
                #endif
            }
            if let problem {
                Text(problem)
                    .font(.caption2)
                    .foregroundStyle(.red)
            } else if !isApplicable {
                Text("Ignored for \(roleTitle) instances")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            } else if let spec, !spec.summary.isEmpty {
                Text(spec.summary)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var valueControl: some View {
        switch spec?.kind {
        case .options(let options):
            Picker("Value", selection: $row.value) {
                ForEach(options) { option in
                    Text(option.title).tag(option.value)
                }
                if !options.contains(where: { $0.value == row.value }) {
                    Text("\(row.value.isEmpty ? "—" : row.value) (custom)").tag(row.value)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()

        case .boolean:
            Toggle("Value", isOn: Binding(get: { row.value == "1" }, set: { row.value = $0 ? "1" : "0" }))
                .labelsHidden()

        case .bitSet(let options):
            Menu {
                ForEach(options) { option in
                    Toggle(isOn: Binding(
                        get: { row.value.contains(option.value) },
                        set: { on in
                            var digits = Set(row.value.filter(\.isNumber).map(String.init))
                            if on { digits.insert(option.value) } else { digits.remove(option.value) }
                            row.value = options.map(\.value).filter { digits.contains($0) }.joined()
                        })) {
                        Text(option.title)
                        if let detail = option.detail { Text(detail) }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(spec?.displayValue(row.value) ?? row.value)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                }
                .font(.callout)
            }

        case .integer:
            HStack(spacing: 4) {
                TextField("Value", text: $row.value, prompt: Text(spec?.defaultValue ?? "0"))
                    .codeInput(.number)
                    .multilineTextAlignment(.trailing)
                    .font(.callout.monospaced())
                    .frame(maxWidth: 120)
                if let unit = spec?.unit {
                    Text(unit)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

        case .duration:
            HStack(spacing: 4) {
                TextField("Value", text: $row.value, prompt: Text(spec?.placeholder ?? spec?.defaultValue ?? "5m"))
                    .multilineTextAlignment(.trailing)
                    .font(.callout.monospaced())
                    .codeInput()
                    .frame(maxWidth: 110)
                Menu {
                    ForEach(["0", "10s", "30s", "1m", "5m", "30m", "1h"], id: \.self) { value in
                        Button(value) { row.value = value }
                    }
                } label: {
                    Image(systemName: "clock")
                        .font(.caption)
                }
            }

        case .suggestions(let options):
            HStack(spacing: 4) {
                textField(prompt: spec?.placeholder)
                Menu {
                    ForEach(options) { option in
                        Button {
                            row.value = option.value
                        } label: {
                            Text(option.title)
                            if let detail = option.detail { Text(detail) }
                        }
                    }
                } label: {
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                }
            }

        case .host:
            HStack(spacing: 4) {
                textField(prompt: spec?.placeholder ?? "host", input: .url)
                if spec?.defaultValue == "auto" {
                    Button("auto") { row.value = "auto" }
                        .font(.caption)
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                }
            }

        case .path, .hostPort, .hex, .text, nil:
            textField(prompt: spec?.placeholder ?? "value", input: spec?.kind == .hostPort ? .url : .plain)
        }
    }

    private func textField(prompt: String?, input: TextInputKind = .plain) -> some View {
        TextField("Value", text: $row.value, prompt: prompt.map { Text($0) })
            .multilineTextAlignment(.trailing)
            .font(.callout.monospaced())
            .codeInput(input)
    }
}

/// Picks a parameter from the catalog or enters a custom key.
struct ParameterPickerView: View {
    @Environment(\.dismiss) private var dismiss

    var specs: [ParameterSpec]
    var onPick: (ParameterSpec) -> Void
    var onCustom: (String) -> Void

    @State private var searchText = ""
    @State private var customKey = ""

    private var filtered: [ParameterSpec] {
        guard !searchText.isEmpty else { return specs }
        return specs.filter {
            $0.key.localizedCaseInsensitiveContains(searchText) || $0.title.localizedCaseInsensitiveContains(searchText) || $0.summary.localizedCaseInsensitiveContains(searchText)
        }
    }


    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        CodeField(title: "Custom key", text: $customKey, prompt: "custom_key")
                        Button("Add") {
                            onCustom(customKey)
                            dismiss()
                        }
                        .disabled(customKey.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                } header: {
                    Text("Custom")
                } footer: {
                    Text("Unknown keys are passed to the master unchanged.")
                }
                ForEach(filtered.groupedByCategory, id: \.group) { entry in
                    Section {
                        ForEach(entry.specs) { spec in
                            Button {
                                onPick(spec)
                                dismiss()
                            } label: {
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack {
                                        Text(spec.title)
                                            .foregroundStyle(Color.accentColor)
                                        Spacer()
                                        Text(spec.key)
                                            .font(.caption.monospaced())
                                            .foregroundStyle(.secondary)
                                    }
                                    Text(spec.summary)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    if let defaultValue = spec.defaultValue {
                                        Text("Default: \(spec.displayValue(defaultValue))")
                                            .font(.caption2.monospaced())
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        Label(entry.group.title, systemImage: entry.group.symbolName)
                    }
                }
            }
            .overlay {
                if filtered.isEmpty, !specs.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else if specs.isEmpty {
                    ContentUnavailableView("All Parameters Set", systemImage: "checkmark.circle", description: Text("Every known parameter is already in use. Add a custom key above."))
                }
            }
            .searchable(text: $searchText, prompt: "Search parameters")
            .navigationTitle("Add Parameter")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark", role: .cancel) { dismiss() }
                }
            }
        }
    }
}

extension Array where Element == ParameterSpec {
    /// Specs bucketed by catalog group, in group order.
    var groupedByCategory: [(group: ParameterGroup, specs: [ParameterSpec])] {
        var buckets: [ParameterGroup: [ParameterSpec]] = [:]
        for spec in self { buckets[spec.group, default: []].append(spec) }
        return buckets.keys.sorted().map { ($0, buckets[$0] ?? []) }
    }
}

/// Trailing minus button for rows that iOS deletes by swiping.
struct RemoveRowButton: View {
    var title: String
    var action: () -> Void

    var body: some View {
        Button(title, systemImage: "minus.circle.fill", action: action)
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .help(title)
    }
}
