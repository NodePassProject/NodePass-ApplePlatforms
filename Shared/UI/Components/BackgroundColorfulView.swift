//
//  BackgroundColorfulView.swift
//  NodePass
//
//  Created by Junhui Lou on 9/23/25.
//

import SwiftUI
import ColorfulX

struct BackgroundColorfulView: View {
    @Environment(\.colorScheme) private var scheme
    
    var body: some View {
        switch(scheme) {
        case .light:
            ColorfulView(color: ColorfulPreset.appleIntelligence)
                .ignoresSafeArea()
        case .dark:
            ColorfulView(color: [
                .init(red: 0.2, green: 0, blue: 0.3),
                .init(red: 0.1, green: 0, blue: 0.2),
                .init(red: 0, green: 0, blue: 0.15),
                .init(red: 0.3, green: 0.1, blue: 0),
                .init(red: 0.05, green: 0.05, blue: 0.1),
                .init(red: 0, green: 0.1, blue: 0.2),
                .init(red: 0.3, green: 0.2, blue: 0),
                .init(red: 0, green: 0.15, blue: 0.1),
                .init(red: 0, green: 0.2, blue: 0.15)
            ])
            .ignoresSafeArea()
        default:
            EmptyView()
        }
    }
}
