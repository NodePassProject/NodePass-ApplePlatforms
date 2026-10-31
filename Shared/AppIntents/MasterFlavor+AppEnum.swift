//
//  MasterFlavor+AppEnum.swift
//  NodePass
//
//  The API flavor as a value Shortcuts can filter and display.
//

import AppIntents

extension MasterFlavor: AppEnum {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Flavor")

    static let caseDisplayRepresentations: [MasterFlavor: DisplayRepresentation] = [
        .nodePass: DisplayRepresentation(title: "NodePass", subtitle: "Master API v1 · server and client instances"),
        .openCtrl: DisplayRepresentation(title: "Nowhere", subtitle: "OpenCtrl API v2 · portal, vector and egress instances"),
    ]
}
