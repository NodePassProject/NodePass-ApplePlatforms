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
                    NPUI.copyToClipboard(string)
                } label: {
                    Label("Copy", systemImage: "document.on.document")
                }
            }
    }
}

extension View {
    func copiable(_ string: String) -> some View {
        modifier(CopiableModifier(string: string))
    }
    
    func copiable(_ int: Int) -> some View {
        modifier(CopiableModifier(string: String(int)))
    }
}
