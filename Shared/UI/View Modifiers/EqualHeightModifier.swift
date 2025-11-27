//
//  EqualHeightModifier.swift
//  NodePass
//
//  Created by Junhui Lou on 11/27/25.
//

import SwiftUI

struct EqualHeightModifier: ViewModifier {
    @Binding var height: CGFloat?
    let alignment: Alignment
    
    func body(content: Content) -> some View {
        content
            .fixedSize()
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear {
                            height = max(height ?? 0, geo.size.height)
                        }
                }
            )
            .frame(height: height, alignment: alignment)
    }
}
