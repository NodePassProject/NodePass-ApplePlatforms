//
//  Binding+Presentation.swift
//  NodePass
//

import SwiftUI

extension Binding where Value == Bool {
    /// `true` while `item` holds a value; setting `false` clears it. Drives alerts that present an
    /// optional item.
    init<Item>(isPresenting item: Binding<Item?>) {
        self.init(
            get: { item.wrappedValue != nil },
            set: { if !$0 { item.wrappedValue = nil } }
        )
    }
}
