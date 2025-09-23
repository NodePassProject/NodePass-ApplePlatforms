//
//  EqualWidthModifier.swift
//  NodePass
//
//  Created by Junhui Lou on 7/4/25.
//

import SwiftUI

struct EqualWidthModifier: ViewModifier {
    @Binding var width: CGFloat?
    
    func body(content: Content) -> some View {
        content
            .fixedSize()
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear {
                            width = max(width ?? 0, geo.size.width)
                        }
                }
            )
            .frame(width: width, alignment: .leading)
    }
}
