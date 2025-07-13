//
//  EditableAndDeletable.swift
//  NodePass
//
//  Created by Junhui Lou on 7/4/25.
//

import SwiftUI

struct EditableAndDeletable: ViewModifier {
    let editAction: () -> Void
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
                    editAction()
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
            }
            .contextMenu {
                Button {
                    editAction()
                } label: {
                    Label("Edit", systemImage: "pencil")
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
    func editableAndDeletable(editAction: @escaping () -> Void, deleteAction: @escaping () -> Void) -> some View {
        modifier(EditableAndDeletable(editAction: editAction, deleteAction: deleteAction))
    }
}
