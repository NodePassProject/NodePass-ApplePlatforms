//
//  Haptics.swift
//  NodePass Watch App
//
//  Feedback for completed operations, through the Taptic Engine.
//

import WatchKit

enum Haptics {
    static func success() {
        WKInterfaceDevice.current().play(.success)
    }

    static func failure() {
        WKInterfaceDevice.current().play(.failure)
    }

    static func click() {
        WKInterfaceDevice.current().play(.click)
    }
}
