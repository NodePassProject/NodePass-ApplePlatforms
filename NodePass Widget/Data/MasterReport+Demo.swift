//
//  MasterReport+Demo.swift
//  NodePass Widget
//
//  Sample data for widget placeholders, the gallery and previews.
//

import Foundation

extension MasterReport {
    static let demo: MasterReport = {
        var info = MasterInfo()
        info.cpuUsage = 23
        info.memoryTotal = 4 * 1024 * 1024 * 1024
        info.memoryUsed = 1_700_000_000
        info.swapTotal = 1024 * 1024 * 1024
        info.swapUsed = 120_000_000
        info.networkReceived = 120_000_000_000
        info.networkTransmitted = 48_000_000_000
        info.uptime = 86_400 * 3 + 3600 * 5
        info.version = "1.9.0"
        info.os = "linux"
        info.architecture = "amd64"
        let instances = [
            demoInstance("edge-tokyo", .server, .running, connections: 148, traffic: 42_000_000_000),
            demoInstance("db-relay", .client, .running, connections: 31, traffic: 9_800_000_000),
            demoInstance("api-gateway", .server, .running, connections: 87, traffic: 18_500_000_000),
            demoInstance("backup-sync", .client, .running, connections: 4, traffic: 3_100_000_000),
            demoInstance("metrics", .client, .running, connections: 12, traffic: 640_000_000),
            demoInstance("staging", .server, .stopped, connections: 0, traffic: 210_000_000),
            demoInstance("lab", .client, .stopped, connections: 0, traffic: 0),
        ]
        return MasterReport(id: "demo-tokyo", name: "Tokyo Edge", info: info, instances: instances)
    }()

    static let demoFleet: [MasterReport] = {
        var frankfurt = demo
        frankfurt = MasterReport(id: "demo-frankfurt", name: "Frankfurt Portal", info: frankfurt.info, instances: Array(frankfurt.instances.prefix(3)))
        frankfurt.info?.cpuUsage = 61
        frankfurt.info?.memoryUsed = 3_100_000_000
        var singapore = MasterReport(id: "demo-singapore", name: "Singapore", info: demo.info, instances: demo.instances)
        singapore.instances[1].status = .error
        singapore.info?.cpuUsage = 8
        let lab = MasterReport(id: "demo-lab", name: "Home Lab", failure: "Timed out")
        return [demo, frankfurt, singapore, lab]
    }()

    private static func demoInstance(_ name: String, _ role: InstanceRole, _ status: InstanceStatus, connections: Int, traffic: UInt64) -> Instance {
        var instance = Instance(id: name)
        instance.alias = name
        instance.role = role
        instance.status = status
        instance.tcpConnections = connections
        instance.tcpReceived = traffic / 3 * 2
        instance.tcpTransmitted = traffic / 3
        return instance
    }
}
