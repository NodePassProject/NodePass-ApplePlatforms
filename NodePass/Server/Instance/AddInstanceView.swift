//
//  AddInstanceView.swift
//  NodePass
//
//  Created by Yosebyte on 1/21/26.
//

import SwiftUI

struct AddInstanceView: View {
    let server: Server
    let onInstanceCreated: () -> Void
    
    init(server: Server, onInstanceCreated: @escaping () -> Void) {
        self.server = server
        self.onInstanceCreated = onInstanceCreated
    }
    
    var body: some View {
        InstanceFormView(server: server, onComplete: onInstanceCreated)
    }
}
