//
//  TCPingResult.swift
//  NodePass
//

import Foundation

nonisolated struct TCPingResult: Codable, Hashable, Sendable {
    var target: String = ""
    var connected: Bool = false
    /// Connection latency in milliseconds (0 on failure).
    var latency: Int64 = 0
    var error: String?

    init(target: String = "", connected: Bool = false, latency: Int64 = 0, error: String? = nil) {
        self.target = target
        self.connected = connected
        self.latency = latency
        self.error = error
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        target = try c.decodeIfPresent(String.self, forKey: .target) ?? ""
        connected = try c.decodeIfPresent(Bool.self, forKey: .connected) ?? false
        latency = try c.decodeIfPresent(Int64.self, forKey: .latency) ?? 0
        error = try c.decodeIfPresent(String.self, forKey: .error)
    }
}
