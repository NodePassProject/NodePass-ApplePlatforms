//
//  ImageAlignment.swift
//  NodePass
//
//  Created by Junhui Lou on 11/27/25.
//

import SwiftUI

extension VerticalAlignment {
    private struct ImageAlignment: AlignmentID {
        static func defaultValue(in context: ViewDimensions) -> CGFloat {
            context[VerticalAlignment.center]
        }
    }
    
    static let imageAlignment = VerticalAlignment(ImageAlignment.self)
}
