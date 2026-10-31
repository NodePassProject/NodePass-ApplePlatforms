//
//  IntentNavigator.swift
//  NodePass
//
//  Where foreground intents send the Mac app. On iOS the scene that the system targets handles
//  `onAppIntentExecution`; macOS has no such hook, so intents go through the app's own link
//  scheme: every main window handles `np://` links and prefers to reuse itself, so an open window
//  shows the destination and the scene creates one when none is open.
//

#if os(macOS)
import AppKit
import Foundation

@MainActor
final class IntentNavigator {
    func show(master id: String) {
        open(DeepLink.master(id))
    }

    func show(instance id: String, on masterID: String) {
        open(DeepLink.master(masterID, instance: id))
    }

    func show(tool: Tool) {
        open(DeepLink.tool(tool.rawValue))
    }

    private func open(_ url: URL) {
        NSWorkspace.shared.open(url)
        NSApp.activate()
    }
}
#endif
