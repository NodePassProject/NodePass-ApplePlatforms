//
//  LoadingStateModifier.swift
//  NodePass
//
//  Created by Junhui Lou on 7/4/25.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct LoadingStateModifier: ViewModifier {
    let loadingState: LoadingState
    let retryAction: () -> Void
    
    func body(content: Content) -> some View {
        ZStack {
#if canImport(UIKit)
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()
#endif
            
            switch(loadingState) {
            case .idle:
                EmptyView()
            case .loading:
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .loaded:
                content
            case .error(let message):
                VStack(spacing: 20) {
                    Text("An error occurred")
                        .font(.headline)
                    Text(message)
                        .font(.subheadline)
                    Button("Reload") {
                        retryAction()
                    }
                }
                .padding()
            }
        }
    }
}

extension View {
    func loadingState(loadingState: LoadingState, retryAction: @escaping () -> Void) -> some View {
        modifier(LoadingStateModifier(loadingState: loadingState, retryAction: retryAction))
    }
}
