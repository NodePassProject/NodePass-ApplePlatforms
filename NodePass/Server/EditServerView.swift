//
//  EditServerView.swift
//  NodePass
//
//  Created by Junhui Lou on 6/30/25.
//

import SwiftUI
import SwiftData

enum EditServerSheetMode {
    case adding
    case editing
}

struct EditServerView: View {
    @Environment(NPState.self) var state
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    
    @Binding var server: Server?
    @State var name: String = ""
    @State var url: String = ""
    @State var key: String = ""
    @State var isShowingScanner: Bool = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                }
                
                Section {
                    TextField("URL", text: $url)
                        .autocorrectionDisabled()
#if os(iOS)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
#endif
                    TextField("Key", text: $key)
                        .autocorrectionDisabled()
#if os(iOS)
                        .textInputAutocapitalization(.never)
#endif
                } footer: {
                    VStack(alignment: .leading) {
                        Text("URL: URL of your master API.")
                        Text("URL Example: https://17.253.144.10:1000/api/v1")
                        Text("Key: API Key of your master API.")
                        Text("Key Example: da101e32c7b8c296c8b0d08fca480edc")
                    }
                }
                
#if os(iOS)
                Section {
                    Button {
                        isShowingScanner = true
                    } label: {
                        Label("Scan QR Code", systemImage: "qrcode.viewfinder")
                    }
                }
#endif
            }
            .formStyle(.grouped)
            .navigationTitle(state.editServerSheetMode == .adding ? "Add Server" : "Edit Server")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if #available(iOS 26.0, macOS 26.0, *) {
                        Button(role: .cancel) {
                            dismiss()
                        } label: {
                            Label("Cancel", systemImage: "xmark")
                        }
                    }
                    else {
                        Button("Cancel", role: .cancel) {
                            dismiss()
                        }
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    if #available(iOS 26.0, macOS 26.0, *) {
                        Button(role: .confirm) {
                            dismiss()
                            confirm()
                        } label: {
                            Label("Done", systemImage: "checkmark")
                        }
                        .disabled(!isValidAPIURL(url) || key == "")
                    }
                    else {
                        Button("Done") {
                            dismiss()
                            confirm()
                        }
                        .disabled(!isValidAPIURL(url) || key == "")
                    }
                }
            }
#if os(iOS)
            .sheet(isPresented: $isShowingScanner) {
                QRCodeScannerView(url: $url, key: $key)
            }
#endif
            .onAppear {
                if let server {
                    name = server.name
                    url = server.url
                    key = server.key
                }
            }
        }
    }
    
    private func isValidAPIURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else {
            return false
        }
        
        guard let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme) else {
            return false
        }
        
        guard url.host != nil else {
            return false
        }
        
        if let port = url.port, !(0...65535).contains(port) {
            return false
        }
        
        return true
    }
    
    private func confirm() {
        switch(state.editServerSheetMode) {
        case .adding:
            if let server {
                server.name = NPCore.noEmptyName(name)
                server.url = url
                server.key = key
                context.insert(server)
            }
            else {
                let server = Server(name: NPCore.noEmptyName(name), url: url, key: key)
                context.insert(server)
            }
        case .editing:
            let server = server!
            server.name = NPCore.noEmptyName(name)
            server.url = url
            server.key = key
        }
    }
}
