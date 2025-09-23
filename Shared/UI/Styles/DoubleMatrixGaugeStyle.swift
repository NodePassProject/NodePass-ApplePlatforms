//
//  DoubleMatrixGaugeStyle.swift
//  NodePass
//
//  Created by Junhui Lou on 9/18/25.
//

import SwiftUI

struct DoubleMatrixGaugeStyle: GaugeStyle {
    let text1: LocalizedStringKey
    let text2: LocalizedStringKey
    let color1: Color
    let color2: Color
    let size: CGFloat
    
    func makeBody(configuration: Configuration) -> some View {
        VStack {
            configuration.label
            Circle()
                .stroke(color2, style: StrokeStyle(lineWidth: size / 10, lineCap: .butt))
                .frame(width: size, height: size)
                .overlay {
                    ZStack {
                        Circle()
                            .trim(from: 0, to: CGFloat(configuration.value))
                            .rotation(.degrees(-90))
                            .stroke(color1, style: StrokeStyle(lineWidth: size / 10, lineCap: .butt))
                            .animation(.default, value: configuration.value)
                        VStack(spacing: 1) {
                            Text(text1)
                            Text(text2)
                        }
                        .font(.system(size: size * 0.2))
                    }
                }
        }
    }
}
