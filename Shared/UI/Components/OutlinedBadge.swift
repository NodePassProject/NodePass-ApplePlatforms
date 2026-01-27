//
//  OutlinedBadge.swift
//  NodePass
//
//  Created by Junhui Lou on 7/4/25.
//

import SwiftUI

struct OutlinedBadge: View {
    let text: String
    let borderColor: Color
    let textColor: Color
    let lineWidth: CGFloat
    
    init(_ text: String,
         borderColor: Color = .blue,
         textColor: Color = .blue,
         lineWidth: CGFloat = 1.0) {
        self.text = text
        self.borderColor = borderColor
        self.textColor = textColor
        self.lineWidth = lineWidth
    }
    
    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold, design: .default))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundColor(textColor)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(borderColor, lineWidth: lineWidth)
            )
    }
}
