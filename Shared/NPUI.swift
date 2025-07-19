//
//  NPUI.swift
//  NodePass
//
//  Created by Junhui Lou on 7/19/25.
//

import SwiftUI

class NPUI {
    // MARK: - Utilities
    static func copyToClipboard(_ string: String) {
#if os(iOS) || os(visionOS)
        UIPasteboard.general.string = string
#endif
#if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
#endif
    }
}
