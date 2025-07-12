//
//  CopiableModifier.swift
//  NodePass
//
//  Created by Junhui Lou on 7/12/25.
//

import SwiftUI

struct CopiableModifier: ViewModifier {
    let string: String
    
    func body(content: Content) -> some View {
        content
            .contextMenu {
                Button {
#if os(iOS) || os(visionOS)
                    UIPasteboard.general.string = string
#endif
#if os(macOS)
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(string, forType: .string)
#endif
                } label: {
                    Label("Copy", systemImage: "document.on.document")
                }
            }
    }
}

extension View {
    func copiable(string: String) -> some View {
        modifier(CopiableModifier(string: string))
    }
}
