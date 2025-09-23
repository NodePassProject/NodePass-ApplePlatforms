//
//  SingleMatrixGaugeStyle.swift
//  NodePass
//
//  Created by Junhui Lou on 9/18/25.
//

import SwiftUI

struct SingleMatrixGaugeStyle: GaugeStyle {
    let color: Color
    let size: CGFloat
    
    func makeBody(configuration: Configuration) -> some View {
        VStack {
            configuration.label
            Circle()
                .stroke(.quaternary, style: StrokeStyle(lineWidth: size / 10, lineCap: .round))
                .frame(width: size, height: size)
                .overlay {
                    ZStack {
                        Circle()
                            .trim(from: 0, to: CGFloat(configuration.value))
                            .rotation(.degrees(-90))
                            .stroke(color, style: StrokeStyle(lineWidth: size / 10, lineCap: .round))
                            .animation(.default, value: configuration.value)
                        Text("\(configuration.value * 100, specifier: "%.0f")%")
                            .font(.system(size: size * 0.35, design: .rounded))
                            .minimumScaleFactor(0.1)
                    }
                }
        }
    }
}
