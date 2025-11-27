//
//  ExternalTarget.swift
//  NodePass
//
//  Created by Junhui Lou on 11/27/25.
//

struct ExternalTarget: Identifiable {
    var id: Int { position }
    var position: Int
    var address: String = ""
    var port: String = ""
}
