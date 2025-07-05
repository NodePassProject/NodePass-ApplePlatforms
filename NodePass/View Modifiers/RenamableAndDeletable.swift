//
//  RenamableAndDeletable.swift
//  NodePass
//
//  Created by Junhui Lou on 7/4/25.
//

import SwiftUI

struct RenamableAndDeletable: ViewModifier {
    let renameAction: () -> Void
    let deleteAction: () -> Void
    
    func body(content: Content) -> some View {
        content
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) {
                    deleteAction()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                
                Button {
                    renameAction()
                } label: {
                    Label("Rename", systemImage: "pencil")
                }
            }
            .contextMenu {
                Button {
                    renameAction()
                } label: {
                    Label("Rename", systemImage: "pencil")
                }
                
                Button(role: .destructive) {
                    deleteAction()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
    }
}

extension View {
    func renamableAndDeletable(renameAction: @escaping () -> Void, deleteAction: @escaping () -> Void) -> some View {
        modifier(RenamableAndDeletable(renameAction: renameAction, deleteAction: deleteAction))
    }
}
