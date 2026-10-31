//
//  WidgetAppBundle.swift
//  NodePass Widget
//

import WidgetKit
import SwiftUI

@main
struct WidgetAppBundle: WidgetBundle {
    var body: some Widget {
        MasterOverviewWidget()
        FleetWidget()
    }
}
