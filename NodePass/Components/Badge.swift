//
//  Badge.swift
//  NodePass
//
//  Created by Junhui Lou on 7/4/25.
//

import SwiftUI

struct Badge: View {
    let text: any StringProtocol
    let backgroundColor: Color
    let textColor: Color
    
    init<S>(_ text: S, backgroundColor: Color = .blue, textColor: Color = .white) where S : StringProtocol {
        self.text = text
        self.backgroundColor = backgroundColor
        self.textColor = textColor
    }
    
    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold, design: .default))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundColor(textColor)
            .background(backgroundColor)
            .cornerRadius(12)
    }
}
