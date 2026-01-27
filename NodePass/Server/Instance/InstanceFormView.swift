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
    @State private var alias: String = ""
    @State private var instanceType: InstanceType = .server
    @State private var tunnelAddress: String = ""
    @State private var tunnelPort: String = ""
    @State private var targetAddress: String = ""
    @State private var targetPort: String = ""
    @State private var isMultipleTargets: Bool = false
    @State private var externalTargets: [ExternalTarget] = []
    @State private var parameters: [InstanceParameter] = []
    @State private var logLevel: LogLevel = .info
    @State private var tlsMode: TLSMode = .none
    @State private var crtPath: String = ""
    @State private var keyPath: String = ""
    @State private var sni: String = ""
    @State private var connectionMode: ConnectionMode = .auto
    @State private var connectionType: Instance.Transport = .tcp
    @State private var minConnections: String = ""
    @State private var maxConnections: String = ""
    @State private var dnsCache: String = ""
    @State private var dialAddress: String = ""
    @State private var readTimeout: String = ""
    @State private var rateLimit: String = ""
    @State private var maxSlots: String = ""
    @State private var disableTCP: Bool = false
    @State private var disableUDP: Bool = false
    @State private var enableProxy: Bool = false
    @State private var blockHTTP: Bool = false
    @State private var blockTLS: Bool = false
    @State private var blockSOCKS: Bool = false
    @State private var lbsStrategy: LoadBalancingStrategy = .roundRobin
    @State private var urlString: String = ""
    @State private var isShowErrorAlert: Bool = false
    @State private var errorMessage: String = ""
    @State private var isSensoryFeedbackTriggered: Bool = false
    
    private var isEditMode: Bool { instance != nil }
    private var title: String { isEditMode ? "Edit Instance" : "Add Instance" }
    private var confirmButtonText: String { isEditMode ? "Save" : "Add" }
    
    private var blockedTrafficString: String {
        var blockedTrafficStrings: [String] = []
        if blockHTTP { blockedTrafficStrings.append("HTTP") }
        if blockTLS { blockedTrafficStrings.append("TLS") }
        if blockSOCKS { blockedTrafficStrings.append("SOCKS") }
        if blockedTrafficStrings.isEmpty {
            return "None"
        }
        return blockedTrafficStrings.joined(separator: ", ")
    }
    
    private var networkTuningSummary: String {
        var settings: [String] = []
        if !dnsCache.isEmpty { settings.append("DNS: \(dnsCache)") }
        if !dialAddress.isEmpty { settings.append("Dial: \(dialAddress)") }
        if !readTimeout.isEmpty { settings.append("Read: \(readTimeout)") }
        if !rateLimit.isEmpty { settings.append("Rate: \(rateLimit)") }
        if !maxSlots.isEmpty { settings.append("Slot: \(maxSlots)") }
        return settings.isEmpty ? "Default" : settings.joined(separator: ", ")
    }
    
    private var protocolControlSummary: String {
        var settings: [String] = []
        if disableTCP { settings.append("TCP Off") }
        if disableUDP { settings.append("UDP Off") }
        if enableProxy { settings.append("PROXY On") }
        return settings.isEmpty ? "Default" : settings.joined(separator: ", ")
    }
    
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
                    TextField("Name", text: $alias)
                        .autocorrectionDisabled()
#if os(iOS)
                        .textInputAutocapitalization(.never)
#endif
                } header: {
                    Text("Instance Alias")
                } footer: {
                    Text("An optional friendly name for this instance.")
                        .foregroundStyle(.secondary)
                }
                
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
                        Text("Configure instance using form fields.")
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Enter instance URL directly.")
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
            .listRowSpacing(0)
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
                    alias = instance.alias ?? ""
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
                Text("Listen on tunnel address and forward to/from target.")
                    .foregroundStyle(.secondary)
            } else {
                Text("Connect to tunnel address and forward from/to target.")
                    .foregroundStyle(.secondary)
            }
        }
        
        Section {
            LabeledTextField("IP", prompt: "Optional", text: $tunnelAddress)
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
                    Text("Tunnel address to bind, empty IP for all interfaces.")
                        .foregroundStyle(.secondary)
                } else {
                    Text("Server address to connect or Client address to bind.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        
        Section {
            Toggle("Multiple Target Addresses", isOn: $isMultipleTargets)
                .onChange(of: isMultipleTargets) {
                    if isMultipleTargets {
                        if externalTargets.isEmpty {
                            externalTargets.append(ExternalTarget(position: 0, address: targetAddress, port: targetPort))
                            externalTargets.append(ExternalTarget(position: 1))
                        }
                    } else {
                        if !externalTargets.isEmpty {
                            targetAddress = externalTargets[0].address
                            targetPort = externalTargets[0].port
                            externalTargets.removeAll()
                        }
                    }
                }
            
            if isMultipleTargets {
                Picker("Load Balancing Strategy", selection: $lbsStrategy) {
                    ForEach(LoadBalancingStrategy.allCases, id: \.self) { strategy in
                        Text(strategy.displayName).tag(strategy)
                    }
                }
                
                ForEach(externalTargets) { externalTarget in
                    LabeledTextField(
                        "IP \(externalTarget.position + 1)",
                        prompt: instanceType == .server ? "" : "",
                        text: Binding(get: {
                            externalTargets[externalTarget.position].address
                        }, set: {
                            externalTargets[externalTarget.position].address = $0
                        })
                    )
                    .autocorrectionDisabled()
#if os(iOS)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
#endif
                    
                    LabeledTextField(
                        "Port \(externalTarget.position + 1)",
                        prompt: "8080",
                        text: Binding(get: {
                            externalTargets[externalTarget.position].port
                        }, set: {
                            externalTargets[externalTarget.position].port = $0
                        }),
                        isNumberOnly: true
                    )
                }
                
                HStack(spacing: 5) {
                    Button {
                        externalTargets.append(ExternalTarget(position: externalTargets.count))
                    } label: {
                        Image(systemName: "plus")
                            .frame(width: 20, height: 20)
                    }
#if os(iOS)
                    .buttonBorderShape(.circle)
                    .buttonStyle(.borderedProminent)
#else
                    .buttonStyle(.borderless)
#endif
                    
                    Button(role: .destructive) {
                        if externalTargets.count == 2 {
                            targetAddress = externalTargets[0].address
                            targetPort = externalTargets[0].port
                            externalTargets.removeAll()
                            isMultipleTargets = false
                        } else {
                            externalTargets.remove(at: externalTargets.endIndex - 1)
                        }
                    } label: {
                        Image(systemName: "minus")
                            .frame(width: 20, height: 20)
                    }
                    .disabled(externalTargets.count < 2)
#if os(iOS)
                    .buttonBorderShape(.circle)
                    .buttonStyle(.borderedProminent)
#else
                    .buttonStyle(.borderless)
#endif
                }
            } else {
                LabeledTextField("IP", prompt: "Optional", text: $targetAddress)
                    .autocorrectionDisabled()
#if os(iOS)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
#endif
                LabeledTextField("Port", prompt: "8080", text: $targetPort, isNumberOnly: true)
            }
        } header: {
            Text("Target Address")
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                if isMultipleTargets {
                    Text("Configure multiple target addresses for load balancing.")
                        .foregroundStyle(.secondary)
                } else {
                    Text("Single target address to connect or to bind.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        
        Section {
            if instanceType == .server {
                Picker("TLS Mode", selection: $tlsMode) {
                    ForEach(TLSMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
            }
            
            if tlsMode == .custom && instanceType == .server {
                LabeledTextField("Certificate Path", prompt: "path/to/cert.pem", text: $crtPath)
                    .autocorrectionDisabled()
#if os(iOS)
                    .textInputAutocapitalization(.never)
#endif
                
                LabeledTextField("Key Path", prompt: "path/to/key.pem", text: $keyPath)
                    .autocorrectionDisabled()
#if os(iOS)
                    .textInputAutocapitalization(.never)
#endif
            }
            
            if instanceType == .client {
                LabeledTextField("SNI Hostname", prompt: "example.com", text: $sni)
                    .autocorrectionDisabled()
#if os(iOS)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
#endif
            }
        } header: {
            Text("Security & Encryption")
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                if instanceType == .server {
                    Text("TLS encryption settings.")
                        .foregroundStyle(.secondary)
                } else {
                    Text("SNI hostname for TLS connections.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        
        Section {
            Picker("Connection Mode", selection: $connectionMode) {
                ForEach(ConnectionMode.allCases, id: \.self) { mode in
                    Text(mode.displayName(forServer: instanceType == .server)).tag(mode)
                }
            }
            
            if instanceType == .server {
                Picker("Connection Type", selection: $connectionType) {
                    ForEach(Instance.Transport.allCases, id: \.self) { type in
                        Text(type.localizedName).tag(type)
                    }
                }
                
                LabeledTextField("Maximum Connections", prompt: "1024", text: $maxConnections, isNumberOnly: true)
            }
            
            if instanceType == .client && (connectionMode == .auto || connectionMode == .dualEnd) {
                LabeledTextField("Minimum Connections", prompt: "64", text: $minConnections, isNumberOnly: true)
            }
        } header: {
            Text("Connection Pool")
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                Text("Configure connection pool behavior and limits.")
                    .foregroundStyle(.secondary)
            }
        }
        
        Section {
            Picker("Logging Level", selection: $logLevel) {
                ForEach(LogLevel.allCases, id: \.self) { level in
                    Text(level.rawValue).tag(level)
                }
            }
            
            NavigationLink {
                NetworkTuningView(
                    dnsCache: $dnsCache,
                    dialAddress: $dialAddress,
                    readTimeout: $readTimeout,
                    rateLimit: $rateLimit,
                    maxSlots: $maxSlots
                )
            } label: {
                HStack {
                    Text("Network Tuning")
                    Spacer()
                    Text(networkTuningSummary)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            
            NavigationLink {
                ProtocolControlView(
                    disableTCP: $disableTCP,
                    disableUDP: $disableUDP,
                    enableProxy: $enableProxy
                )
            } label: {
                HStack {
                    Text("Protocol Control")
                    Spacer()
                    Text(protocolControlSummary)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            
            NavigationLink {
                TrafficBlockingView(blockHTTP: $blockHTTP, blockTLS: $blockTLS, blockSOCKS: $blockSOCKS)
            } label: {
                HStack {
                    Text("Traffic Blocking")
                    Spacer()
                    Text(blockedTrafficString)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        } header: {
            Text("Advanced Settings")
        } footer: {
            Text("Configure advanced settings and tuning parameters.")
                .foregroundStyle(.secondary)
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
                .listRowSeparator(.hidden)
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
                Text("Add custom URL query parameters not covered above.")
                    .foregroundStyle(.secondary)
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
        
        let pathString = urlComponents.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        
        if pathString.contains(",") {
            let addressPairs = pathString.components(separatedBy: ",")
            isMultipleTargets = true
            externalTargets = addressPairs.enumerated().compactMap { index, pair in
                let components = pair.components(separatedBy: ":")
                guard components.count >= 2 else { return nil }
                let address = components[0].trimmingCharacters(in: .whitespaces)
                let port = components[1].trimmingCharacters(in: .whitespaces)
                return ExternalTarget(position: index, address: address, port: port)
            }
            if !externalTargets.isEmpty {
                targetAddress = externalTargets[0].address
                targetPort = externalTargets[0].port
            }
        } else {
            let pathComponents = pathString.components(separatedBy: ":")
            if pathComponents.count >= 2 {
                targetAddress = pathComponents[0]
                targetPort = pathComponents[1]
                isMultipleTargets = false
                externalTargets = []
            }
        }
        
        if let queryItems = urlComponents.queryItems {
            var parsedParams: [InstanceParameter] = []
            var position = 0
            
            for item in queryItems {
                let key = item.name
                let value = item.value ?? ""
                
                var isRecognized = false
                
                if key == "tls" {
                    if let mode = TLSMode(rawValue: value) {
                        tlsMode = mode
                        isRecognized = true
                    }
                } else if key == "crt" {
                    crtPath = value
                    isRecognized = true
                } else if key == "key" {
                    keyPath = value
                    isRecognized = true
                } else if key == "sni" {
                    sni = value
                    isRecognized = true
                }
                
                else if key == "mode" {
                    if let mode = ConnectionMode(rawValue: value) {
                        connectionMode = mode
                        isRecognized = true
                    }
                } else if key == "type" {
                    if let type = Instance.Transport(rawValue: value) {
                        connectionType = type
                        isRecognized = true
                    }
                } else if key == "min" {
                    minConnections = value
                    isRecognized = true
                } else if key == "max" {
                    maxConnections = value
                    isRecognized = true
                }
                
                else if key == "dns" {
                    dnsCache = value
                    isRecognized = true
                } else if key == "dial" {
                    dialAddress = value
                    isRecognized = true
                } else if key == "read" {
                    readTimeout = value
                    isRecognized = true
                } else if key == "rate" {
                    rateLimit = value
                    isRecognized = true
                } else if key == "slot" {
                    maxSlots = value
                    isRecognized = true
                }
                
                else if key == "notcp" {
                    disableTCP = value == "1"
                    isRecognized = true
                } else if key == "noudp" {
                    disableUDP = value == "1"
                    isRecognized = true
                } else if key == "proxy" {
                    enableProxy = value == "1"
                    isRecognized = true
                } else if key == "block" {
                    blockSOCKS = value.contains("1")
                    blockHTTP = value.contains("2")
                    blockTLS = value.contains("3")
                    isRecognized = true
                }
                
                else if key == "lbs" {
                    if let strategy = LoadBalancingStrategy(rawValue: value) {
                        lbsStrategy = strategy
                        isRecognized = true
                    }
                }
                
                else if key == "log" {
                    if let level = LogLevel(rawValue: value) {
                        logLevel = level
                        isRecognized = true
                    }
                }
                
                if !isRecognized {
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
        
        let targetPath: String
        
        if isMultipleTargets && !externalTargets.isEmpty {
            let addressPairs = externalTargets.map { target -> String in
                let addr = target.address.isEmpty ? "" : target.address
                let port = target.port.isEmpty ? "8080" : target.port
                return "\(addr):\(port)"
            }.joined(separator: ",")
            targetPath = addressPairs
        } else {
            let targetAddr = targetAddress.isEmpty ? (instanceType == .server ? "" : "") : targetAddress
            let targetPt = targetPort.isEmpty ? "8080" : targetPort
            targetPath = "\(targetAddr):\(targetPt)"
        }
        
        var url: String
        if instanceType == .server {
            url = "server://\(tunnelAddr):\(tunnelPt)/\(targetPath)"
        } else {
            url = "client://\(tunnelAddr):\(tunnelPt)/\(targetPath)"
        }
        
        var queryParams: [String] = []
        
        if instanceType == .server && tlsMode != .none {
            queryParams.append("tls=\(tlsMode.rawValue)")
            if tlsMode == .custom {
                if !crtPath.isEmpty {
                    queryParams.append("crt=\(crtPath)")
                }
                if !keyPath.isEmpty {
                    queryParams.append("key=\(keyPath)")
                }
            }
        }
        if instanceType == .client && !sni.isEmpty {
            queryParams.append("sni=\(sni)")
        }
        
        if connectionMode != .auto {
            queryParams.append("mode=\(connectionMode.rawValue)")
        }
        if connectionMode == .dualEnd {
            if instanceType == .server && connectionType != .tcp {
                queryParams.append("type=\(connectionType.rawValue)")
            }
            if instanceType == .client && !minConnections.isEmpty {
                queryParams.append("min=\(minConnections)")
            }
            if instanceType == .server && !maxConnections.isEmpty {
                queryParams.append("max=\(maxConnections)")
            }
        }
        
        if !dnsCache.isEmpty {
            queryParams.append("dns=\(dnsCache)")
        }
        if !dialAddress.isEmpty {
            queryParams.append("dial=\(dialAddress)")
        }
        if !readTimeout.isEmpty {
            queryParams.append("read=\(readTimeout)")
        }
        if !rateLimit.isEmpty {
            queryParams.append("rate=\(rateLimit)")
        }
        if !maxSlots.isEmpty {
            queryParams.append("slot=\(maxSlots)")
        }
        
        if disableTCP {
            queryParams.append("notcp=1")
        }
        if disableUDP {
            queryParams.append("noudp=1")
        }
        if enableProxy {
            queryParams.append("proxy=1")
        }
        
        var blockValue = ""
        if blockSOCKS { blockValue += "1" }
        if blockHTTP { blockValue += "2" }
        if blockTLS { blockValue += "3" }
        if !blockValue.isEmpty {
            queryParams.append("block=\(blockValue)")
        }
        
        if isMultipleTargets && lbsStrategy != .roundRobin {
            queryParams.append("lbs=\(lbsStrategy.rawValue)")
        }
        
        if logLevel != .info {
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
                errorMessage = "Both tunnel port and target port must be specified."
                isShowErrorAlert = true
                return
            }
        }
        
        let url = inputMode == .url ? urlString : generateURL()
        let aliasValue = NPCore.noEmptyName(alias)
        
        Task {
            let instanceService = InstanceService()
            do {
                if let instance = instance {
                    if instance.url != url {
                        do {
                            _ = try await instanceService.updateInstance(
                                baseURLString: server.url,
                                apiKey: server.key,
                                id: instance.id,
                                url: url
                            )
                        } catch {
                            if !error.localizedDescription.contains("409") {
                                throw error
                            }
                        }
                    }
                    if NPCore.noEmptyName(instance.alias ?? "") != aliasValue {
                        try await instanceService.updateInstanceAlias(
                            baseURLString: server.url,
                            apiKey: server.key,
                            id: instance.id,
                            alias: aliasValue
                        )
                    }
                } else {
                    _ = try await instanceService.createInstance(
                        baseURLString: server.url,
                        apiKey: server.key,
                        url: url,
                        alias: aliasValue
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
