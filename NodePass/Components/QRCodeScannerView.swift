//
//  QRCodeScannerView.swift
//  NodePass
//
//  Created by Junhui Lou on 7/9/25.
//

import SwiftUI
import AVFoundation
import CodeScanner

#if os(iOS)
struct QRCodeScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var url: String
    @Binding var key: String
    
    var body: some View {
        NavigationStack {
            CodeScannerView(codeTypes: [.qr], scanMode: .continuous, showViewfinder: true) { response in
                if case let .success(result) = response {
                    guard let url = URL(string: result.string) else {
#if DEBUG
                        print("Invalid URL string")
#endif
                        return
                    }
                    
                    if url.host == "master" {
                        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
                              let queryItems = components.queryItems else {
#if DEBUG
                            print("Failed to parse URL components")
#endif
                            return
                        }
                        
                        var result = [String: String]()
                        
                        for item in queryItems {
                            if let value = item.value,
                               let decodedData = Data(base64Encoded: value),
                               let decodedString = String(data: decodedData, encoding: .utf8) {
                                result[item.name] = decodedString
                            }
                        }
                        
                        self.url = result["url"] ?? ""
                        self.key = result["key"] ?? ""
                        
                        dismiss()
                        return
                    }
#if DEBUG
                    print("Invalid host")
#endif
                    return
                }
            }
            .ignoresSafeArea()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Label("Cancel", systemImage: "xmark")
                    }
                }
            }
        }
    }
}
#endif
