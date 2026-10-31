//
//  DeepLink.swift
//  NodePass
//
//  Links into the app. `np://master?id=<master>[&instance=<instance>]` shows a master and
//  optionally selects one of its instances; `np://master?url=…&key=…` imports a master;
//  `np://tool?id=<tool>` shows one of the tools.
//

import Foundation

nonisolated enum DeepLink {
    static func master(_ masterID: String, instance instanceID: String? = nil) -> URL {
        var components = URLComponents()
        components.scheme = NPCore.urlScheme
        components.host = "master"
        components.queryItems = [URLQueryItem(name: "id", value: masterID)]
        if let instanceID {
            components.queryItems?.append(URLQueryItem(name: "instance", value: instanceID))
        }
        // A scheme, a host and query items always form a valid URL.
        return components.url!
    }

    /// Shows a tool by its raw identifier (`tcping`, `urlInspector`, `apiConsole`).
    static func tool(_ toolID: String) -> URL {
        var components = URLComponents()
        components.scheme = NPCore.urlScheme
        components.host = "tool"
        components.queryItems = [URLQueryItem(name: "id", value: toolID)]
        return components.url!
    }
}
