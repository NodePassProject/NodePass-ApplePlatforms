//
//  DeepLink.swift
//  NodePass
//
//  Links into the app. `np://master?id=<master>[&instance=<instance>]` shows a master and
//  optionally selects one of its instances; `np://master?url=…&key=…` imports a master.
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
}
