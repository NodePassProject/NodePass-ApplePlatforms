//
//  InstanceFormView.swift
//  NodePass
//
//  Created by Yosebyte on 1/21/26.
//

import SwiftUI

struct InstanceFormView: View {
    @Environment(\.dismiss) private var dismiss
    
    private var isAdvancedModeEnabled: Bool = NPCore.isAdvancedModeEnabled
    
    let server: Server
    let instance: Instance?
    let onComplete: () -> Void
    
    @State private var inputMode: InputMode = .form
    @State private var instanceType: InstanceType = .server
    @State private var tunnelAddress: String = ""
    @State private var tunnelPort: String = ""
    @State private var targetAddress: String = ""
    @State private var targetPort: String = ""
    @State private var parameters: [InstanceParameter] = []
    @State private var logLevel: LogLevel = .info
    @State private var urlString: String = ""
    @State private var isShowErrorAlert: Bool = false
    @State private var errorMessage: String = ""
    @State private var isSensoryFeedbackTriggered: Bool = false
    
    private var isEditMode: Bool { instance != nil }
    private var title: String { isEditMode ? "Edit Instance" : "Add Instance" }
    private var confirmButtonText: String { isEditMode ? "Save" : "Add" }
    
    enum InputMode: String, CaseIterable {
        case form = "Form"
        case url = "URL"
    }
    
    enum InstanceType: String, CaseIterable {
        case server = "Server"
        case client = "Client"
    }
    
    init(server: Server, instance: Instance? = nil, onComplete: @escaping () -> Void) {
        self.server = server
        self.instance = instance
        self.onComplete = onComplete
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Input Mode", selection: $inputMode) {
                        ForEach(InputMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Input Method")
                } footer: {
                    if inputMode == .form {
                        Text("Configure instance using form fields")
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Enter instance URL directly")
                            .foregroundStyle(.secondary)
                    }
                }
                
                if inputMode == .form {
                    formModeContent
                } else {
                    urlModeContent
                }
                
                if inputMode == .form {
                    Section("Preview") {
                        let command = generateURL()
                        Text(command)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
            }
            .formStyle(.grouped)
#if os(iOS)
            .listRowSpacing(5)
#endif
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if #available(iOS 26.0, macOS 26.0, *) {
                        Button(role: .cancel) {
                            dismiss()
                        } label: {
                            Label("Cancel", systemImage: "xmark")
                        }
                    } else {
                        Button("Cancel", role: .cancel) {
                            dismiss()
                        }
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    if #available(iOS 26.0, macOS 26.0, *) {
                        Button(role: .confirm) {
                            saveInstance()
                        } label: {
                            Label(confirmButtonText, systemImage: "checkmark")
                        }
                    } else {
                        Button(confirmButtonText) {
                            saveInstance()
                        }
                    }
                }
            }
            .alert("Error", isPresented: $isShowErrorAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .sensoryFeedback(.success, trigger: isSensoryFeedbackTriggered)
            .onAppear {
                if let instance = instance {
                    parseInstanceURL(instance.url)
                }
            }
        }
    }
    
    @ViewBuilder
    private var formModeContent: some View {
        Section {
            Picker("Instance Type", selection: $instanceType) {
                ForEach(InstanceType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
        } header: {
            Text("Instance Type")
        } footer: {
            if instanceType == .server {
                Text("Listen on tunnel address and forward to/from target")
                    .foregroundStyle(.secondary)
            } else {
                Text("Connect to tunnel address and forward from/to target")
                    .foregroundStyle(.secondary)
            }
        }
        
        Section {
            LabeledTextField("Address", prompt: instanceType == .server ? "" : "", text: $tunnelAddress)
                .autocorrectionDisabled()
#if os(iOS)
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
#endif
            LabeledTextField("Port", prompt: "10101", text: $tunnelPort, isNumberOnly: true)
        } header: {
            Text("Tunnel \(instanceType == .server ? "Bind" : "Server") Address")
        } footer: {
            VStack(alignment: .leading) {
                if instanceType == .server {
                    Text("Address to bind (blank for all interfaces)")
                        .foregroundStyle(.secondary)
                } else {
                    Text("Server address to connect or to bind")
                        .foregroundStyle(.secondary)
                }
            }
        }
        
        Section {
            LabeledTextField("Address", prompt: instanceType == .server ? "" : "", text: $targetAddress)
                .autocorrectionDisabled()
#if os(iOS)
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
#endif
            LabeledTextField("Port", prompt: "8080", text: $targetPort, isNumberOnly: true)
        } header: {
            Text("Target Address")
        } footer: {
            VStack(alignment: .leading) {
                Text("Service address to connect or to bind")
                    .foregroundStyle(.secondary)
            }
        }
        
        Section {
            ForEach(parameters) { parameter in
                HStack(spacing: 8) {
                    TextField("key", text: Binding(get: {
                        parameters[parameter.position].key
                    }, set: {
                        parameters[parameter.position].key = $0
                    }))
                    .autocorrectionDisabled()
#if os(iOS)
                    .textInputAutocapitalization(.never)
#endif
                    .textFieldStyle(.roundedBorder)
                    
                    Text("=")
                        .foregroundStyle(.secondary)
                    
                    TextField("value", text: Binding(get: {
                        parameters[parameter.position].value
                    }, set: {
                        parameters[parameter.position].value = $0
                    }))
                    .autocorrectionDisabled()
#if os(iOS)
                    .textInputAutocapitalization(.never)
#endif
                    .textFieldStyle(.roundedBorder)
                    
                    Button(role: .destructive) {
                        withAnimation {
                            parameters.removeAll { $0.id == parameter.id }
                            for (index, _) in parameters.enumerated() {
                                parameters[index].position = index
                            }
                        }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.borderless)
                }
            }
            
            Button {
                withAnimation {
                    parameters.append(InstanceParameter(position: parameters.count))
                }
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Parameter")
                }
            }
        } header: {
            Text("Additional Parameters")
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                Text("Add custom URL query parameters")
                    .foregroundStyle(.secondary)
            }
        }
        
        if isAdvancedModeEnabled {
            Section {
                Picker("Log Level", selection: $logLevel) {
                    ForEach(LogLevel.allCases, id: \.self) { level in
                        Text(level.rawValue).tag(level)
                    }
                }
            } header: {
                Text("Advanced Options")
            }
        }
    }
    
    @ViewBuilder
    private var urlModeContent: some View {
        Section {
            TextField("URL", text: $urlString, axis: .vertical)
                .autocorrectionDisabled()
#if os(iOS)
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
#endif
                .lineLimit(3...6)
        } header: {
            Text("Instance URL")
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                Text("Visit https://github.com/NodePassProject for documentation on instance URL parameters.")
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private func parseInstanceURL(_ url: String) {
        urlString = url
        
        guard let urlComponents = URLComponents(string: url) else { return }
        
        instanceType = url.hasPrefix("server://") ? .server : .client
        
        tunnelAddress = urlComponents.host ?? ""
        tunnelPort = urlComponents.port.map { String($0) } ?? ""
        
        let pathComponents = urlComponents.path.components(separatedBy: ":")
        if pathComponents.count >= 2 {
            targetAddress = pathComponents[0].trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            targetPort = pathComponents[1]
        }
        
        if let queryItems = urlComponents.queryItems {
            var parsedParams: [InstanceParameter] = []
            var position = 0
            
            for item in queryItems {
                let key = item.name
                let value = item.value ?? ""
                
                if key == "log", isAdvancedModeEnabled {
                    if let level = LogLevel(rawValue: value) {
                        logLevel = level
                    }
                } else {
                    parsedParams.append(InstanceParameter(position: position, key: key, value: value))
                    position += 1
                }
            }
            
            parameters = parsedParams
        }
    }
    
    private func generateURL() -> String {
        let tunnelAddr = tunnelAddress.isEmpty ? (instanceType == .server ? "" : "") : tunnelAddress
        let tunnelPt = tunnelPort.isEmpty ? "10101" : tunnelPort
        let targetAddr = targetAddress.isEmpty ? (instanceType == .server ? "" : "") : targetAddress
        let targetPt = targetPort.isEmpty ? "8080" : targetPort
        
        var url: String
        if instanceType == .server {
            url = "server://\(tunnelAddr):\(tunnelPt)/\(targetAddr):\(targetPt)"
        } else {
            url = "client://\(tunnelAddr):\(tunnelPt)/\(targetAddr):\(targetPt)"
        }
        
        var queryParams: [String] = []
        
        if isAdvancedModeEnabled {
            queryParams.append("log=\(logLevel.rawValue)")
        }
        
        for parameter in parameters where !parameter.key.isEmpty {
            let value = parameter.value.isEmpty ? "" : parameter.value
            queryParams.append("\(parameter.key)=\(value)")
        }
        
        if !queryParams.isEmpty {
            url += "?" + queryParams.joined(separator: "&")
        }
        
        return url
    }
    
    private func saveInstance() {
        if inputMode == .form {
            if tunnelPort.isEmpty || targetPort.isEmpty {
                errorMessage = "Tunnel and target ports are required"
                isShowErrorAlert = true
                return
            }
        }
        
        let url = inputMode == .url ? urlString : generateURL()
        
        Task {
            let instanceService = InstanceService()
            do {
                if let instance = instance {
                    _ = try await instanceService.updateInstance(
                        baseURLString: server.url,
                        apiKey: server.key,
                        id: instance.id,
                        url: url
                    )
                } else {
                    _ = try await instanceService.createInstance(
                        baseURLString: server.url,
                        apiKey: server.key,
                        url: url
                    )
                }
                await MainActor.run {
                    isSensoryFeedbackTriggered.toggle()
                    onComplete()
                    dismiss()
                }
            } catch {
#if DEBUG
                print("Error \(isEditMode ? "Updating" : "Creating") Instance: \(error.localizedDescription)")
#endif
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isShowErrorAlert = true
                }
            }
        }
    }
}
