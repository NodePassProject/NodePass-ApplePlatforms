//
//  MasterInfo.swift
//  NodePass
//
//  Response of `GET /info`: master identity plus host system metrics.
//  System metrics are only populated on Linux hosts; elsewhere they are 0 / -1.
//

import Foundation

nonisolated struct MasterInfo: Codable, Hashable, Sendable {
    /// 16-character hexadecimal master identifier.
    var masterID: String = ""
    var alias: String = ""
    var os: String = ""
    var architecture: String = ""
    /// Logical CPU count.
    var cpuCount: Int = 0
    /// CPU utilisation 0–100, or -1 when unavailable.
    var cpuUsage: Int = -1
    var memoryTotal: UInt64 = 0
    var memoryUsed: UInt64 = 0
    var swapTotal: UInt64 = 0
    var swapUsed: UInt64 = 0
    var networkReceived: UInt64 = 0
    var networkTransmitted: UInt64 = 0
    var diskRead: UInt64 = 0
    var diskWritten: UInt64 = 0
    /// Host uptime in seconds.
    var systemUptime: UInt64 = 0
    var version: String = ""
    var hostname: String = ""
    /// Master process uptime in seconds.
    var uptime: UInt64 = 0
    var logLevel: String = ""
    /// TLS mode of the API itself: "0", "1" or "2".
    var tlsMode: String = ""
    var certificatePath: String = ""
    var keyPath: String = ""

    enum CodingKeys: String, CodingKey {
        case alias, os, cpu, ver, name, uptime, log, tls, crt, key
        case masterID = "mid"
        case architecture = "arch"
        case cpuCount = "noc"
        case memoryTotal = "mem_total"
        case memoryUsed = "mem_used"
        case swapTotal = "swap_total"
        case swapUsed = "swap_used"
        case networkReceived = "netrx"
        case networkTransmitted = "nettx"
        case diskRead = "diskr"
        case diskWritten = "diskw"
        case systemUptime = "sysup"
    }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        masterID = try c.decodeIfPresent(String.self, forKey: .masterID) ?? ""
        alias = try c.decodeIfPresent(String.self, forKey: .alias) ?? ""
        os = try c.decodeIfPresent(String.self, forKey: .os) ?? ""
        architecture = try c.decodeIfPresent(String.self, forKey: .architecture) ?? ""
        cpuCount = try c.decodeIfPresent(Int.self, forKey: .cpuCount) ?? 0
        cpuUsage = try c.decodeIfPresent(Int.self, forKey: .cpu) ?? -1
        memoryTotal = try c.decodeIfPresent(UInt64.self, forKey: .memoryTotal) ?? 0
        memoryUsed = try c.decodeIfPresent(UInt64.self, forKey: .memoryUsed) ?? 0
        swapTotal = try c.decodeIfPresent(UInt64.self, forKey: .swapTotal) ?? 0
        swapUsed = try c.decodeIfPresent(UInt64.self, forKey: .swapUsed) ?? 0
        networkReceived = try c.decodeIfPresent(UInt64.self, forKey: .networkReceived) ?? 0
        networkTransmitted = try c.decodeIfPresent(UInt64.self, forKey: .networkTransmitted) ?? 0
        diskRead = try c.decodeIfPresent(UInt64.self, forKey: .diskRead) ?? 0
        diskWritten = try c.decodeIfPresent(UInt64.self, forKey: .diskWritten) ?? 0
        systemUptime = try c.decodeIfPresent(UInt64.self, forKey: .systemUptime) ?? 0
        version = try c.decodeIfPresent(String.self, forKey: .ver) ?? ""
        hostname = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        uptime = try c.decodeIfPresent(UInt64.self, forKey: .uptime) ?? 0
        logLevel = try c.decodeIfPresent(String.self, forKey: .log) ?? ""
        tlsMode = try c.decodeIfPresent(String.self, forKey: .tls) ?? ""
        certificatePath = try c.decodeIfPresent(String.self, forKey: .crt) ?? ""
        keyPath = try c.decodeIfPresent(String.self, forKey: .key) ?? ""
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(masterID, forKey: .masterID)
        try c.encode(alias, forKey: .alias)
        try c.encode(os, forKey: .os)
        try c.encode(architecture, forKey: .architecture)
        try c.encode(cpuCount, forKey: .cpuCount)
        try c.encode(cpuUsage, forKey: .cpu)
        try c.encode(memoryTotal, forKey: .memoryTotal)
        try c.encode(memoryUsed, forKey: .memoryUsed)
        try c.encode(swapTotal, forKey: .swapTotal)
        try c.encode(swapUsed, forKey: .swapUsed)
        try c.encode(networkReceived, forKey: .networkReceived)
        try c.encode(networkTransmitted, forKey: .networkTransmitted)
        try c.encode(diskRead, forKey: .diskRead)
        try c.encode(diskWritten, forKey: .diskWritten)
        try c.encode(systemUptime, forKey: .systemUptime)
        try c.encode(version, forKey: .ver)
        try c.encode(hostname, forKey: .name)
        try c.encode(uptime, forKey: .uptime)
        try c.encode(logLevel, forKey: .log)
        try c.encode(tlsMode, forKey: .tls)
        try c.encode(certificatePath, forKey: .crt)
        try c.encode(keyPath, forKey: .key)
    }

    // MARK: Derived

    /// Whether the host reports system metrics (Linux only).
    var hasSystemMetrics: Bool { cpuUsage >= 0 || memoryTotal > 0 }

    var cpuRatio: Double { cpuUsage < 0 ? 0 : Double(cpuUsage) / 100 }
    var memoryRatio: Double { memoryTotal == 0 ? 0 : Double(memoryUsed) / Double(memoryTotal) }
    var swapRatio: Double { swapTotal == 0 ? 0 : Double(swapUsed) / Double(swapTotal) }

    var tlsModeTitle: String {
        switch tlsMode {
        case "0": "No TLS"
        case "1": "Self-signed certificate"
        case "2": "Custom certificate"
        case "": "Unknown"
        default: tlsMode
        }
    }

    var displayName: String {
        if !alias.isEmpty { return alias }
        if !hostname.isEmpty { return hostname }
        return masterID
    }
}
