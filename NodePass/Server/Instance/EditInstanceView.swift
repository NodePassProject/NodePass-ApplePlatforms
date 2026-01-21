//
//  EditInstanceView.swift
//  NodePass
//
//  Created by Yosebyte on 1/21/26.
//

import SwiftUI

struct EditInstanceView: View {
    let server: Server
    let instance: Instance
    let onInstanceUpdated: () -> Void
    
    init(server: Server, instance: Instance, onInstanceUpdated: @escaping () -> Void) {
        self.server = server
        self.instance = instance
        self.onInstanceUpdated = onInstanceUpdated
    }
    
    var body: some View {
        InstanceFormView(server: server, instance: instance, onComplete: onInstanceUpdated)
    }
}
