//
//  QRCodeScannerView.swift
//  NodePass
//
//  Scans `np://master?...` codes and hands back a `MasterImport`.
//

import SwiftUI
import CodeScanner
import AVFoundation

struct QRCodeScannerView: View {
    @Environment(\.dismiss) private var dismiss
    var onScan: (MasterImport) -> Void

    @State private var failure: String?

    var body: some View {
        NavigationStack {
            CodeScannerView(codeTypes: [.qr], scanMode: .continuous, showViewfinder: true) { response in
                switch response {
                case .success(let result):
                    guard let url = URL(string: result.string), let master = MasterImport(deepLink: url) else {
                        failure = "This code is not a NodePass master link."
                        return
                    }
                    Haptics.success()
                    onScan(master)
                    dismiss()
                case .failure(let error):
                    failure = error.localizedDescription
                }
            }
            .ignoresSafeArea()
            .overlay(alignment: .bottom) {
                if let failure {
                    InlineMessage(text: failure, style: .warning)
                        .padding()
                }
            }
            .navigationTitle("Scan Master Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark", role: .cancel) { dismiss() }
                }
            }
        }
    }
}
