//
//  Haptics.swift
//  NodePass
//
//  Feedback for completed operations. iPhone only: on macOS, trackpad haptics are reserved for
//  alignment and level changes, so operations stay silent there.
//

import Foundation
#if os(iOS)
import UIKit
#endif

enum Haptics {
    static func success() {
        #if os(iOS)
        guard isEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }

    static func warning() {
        #if os(iOS)
        guard isEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        #endif
    }

    static func selection() {
        #if os(iOS)
        guard isEnabled else { return }
        UISelectionFeedbackGenerator().selectionChanged()
        #endif
    }

    private static var isEnabled: Bool {
        NPCore.userDefaults.bool(forKey: NPCore.DefaultsKey.hapticsEnabled)
    }
}
