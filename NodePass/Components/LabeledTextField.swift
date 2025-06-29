//
//  LabeledTextField.swift
//  NodePass
//
//  Created by Junhui Lou on 7/4/25.
//

import SwiftUI

struct LabeledTextField: View {
    let title: LocalizedStringKey
    let prompt: String
    var text: Binding<String>
    let isNumberOnly: Bool
    
    init(_ title: LocalizedStringKey, prompt: String, text: Binding<String>) {
        self.title = title
        self.prompt = prompt
        self.text = text
        self.isNumberOnly = false
    }
    
    init(_ title: LocalizedStringKey, prompt: String, text: Binding<String>, isNumberOnly: Bool) {
        self.title = title
        self.prompt = prompt
        self.text = text
        self.isNumberOnly = isNumberOnly
    }
    
    var body: some View {
#if os(iOS)
        HStack {
            Text(title)
                .fixedSize()
            if isNumberOnly {
                TextField(prompt, text: text)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.numberPad)
            }
            else {
                TextField(prompt, text: text)
                    .multilineTextAlignment(.trailing)
            }
        }
#else
        TextField(title, text: text, prompt: Text(prompt))
#endif
    }
}
