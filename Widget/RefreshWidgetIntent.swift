//
//  RefreshWidgetIntent.swift
//  NodePass
//
//  Created by Junhui Lou on 9/22/25.
//

import AppIntents

struct RefreshWidgetIntent: AppIntent {
    static let title: LocalizedStringResource = "Refresh Widget"
    static let description = IntentDescription("Get up-to-date information in your Widget.")
    
    func perform() async throws -> some IntentResult {
        return .result()
    }
}
