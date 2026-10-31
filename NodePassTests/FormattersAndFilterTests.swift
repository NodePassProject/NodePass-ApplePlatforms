//
//  FormattersAndFilterTests.swift
//  NodePassTests
//

import Foundation
import Testing
@testable import NodePass

struct FormattersAndFilterTests {
    @Test func bytes() {
        #expect(Format.bytes(UInt64(0)) == "0 B")
        #expect(Format.bytes(UInt64(1024)) == "1 KB")
        #expect(Format.bytes(UInt64(1_610_612_736)) == "1.5 GB")
    }

    @Test func rates() {
        #expect(Format.bitRate(bytesPerSecond: 125_000) == "1 Mbps")
        #expect(Format.bitRate(bytesPerSecond: 0) == "0 bps")
    }

    @Test func durations() {
        #expect(Format.duration(seconds: UInt64(45)) == "45s")
        #expect(Format.duration(seconds: UInt64(3_725)) == "1h 2m")
        #expect(Format.duration(seconds: UInt64(90_000)) == "1d 1h")
        #expect(Format.duration(seconds: UInt64(90_000), compact: true) == "1d")
    }

    @Test func logLineLevelDetectionAndANSIStripping() {
        let line = LogLine(rawText: "\u{1B}[31m2026-10-31 12:00:00.000  ERROR  Server error: dial failed\u{1B}[0m")
        #expect(line.level == .error)
        #expect(!line.text.contains("\u{1B}"))
        #expect(LogLine(rawText: "2026-10-31 12:00:00.000  DEBUG  pool ready").level == .debug)
    }

    @Test func filterSearchesTagsAndText() {
        var a = Instance(id: "a1")
        a.alias = "edge-tokyo"
        a.role = .server
        a.status = .running
        a.meta.tags = ["env": "prod"]
        var b = Instance(id: "b2")
        b.alias = "lab"
        b.role = .client
        b.status = .stopped
        b.meta.tags = ["env": "dev"]

        var filter = InstanceFilter()
        filter.searchText = "env:prod"
        #expect(filter.apply(to: [a, b]).map(\.id) == ["a1"])

        filter.searchText = "#env"
        #expect(filter.apply(to: [a, b]).count == 2)

        filter.searchText = "lab"
        #expect(filter.apply(to: [a, b]).map(\.id) == ["b2"])

        filter = InstanceFilter()
        filter.statuses = [.running]
        #expect(filter.apply(to: [a, b]).map(\.id) == ["a1"])

        filter = InstanceFilter()
        filter.sortKey = .status
        #expect(filter.apply(to: [b, a]).map(\.id) == ["a1", "b2"])

        filter.grouping = .tag
        filter.groupingTagKey = "env"
        let groups = filter.grouped([a, b])
        #expect(groups.map(\.title) == ["env: dev", "env: prod"])
    }

    @Test func sortingIsStrictInBothDirections() {
        var a = Instance(id: "a")
        a.alias = "alpha"
        a.tcpReceived = 100
        var b = Instance(id: "b")
        b.alias = "bravo"
        b.tcpReceived = 100
        var c = Instance(id: "c")
        c.alias = "charlie"
        c.tcpReceived = 500

        var filter = InstanceFilter()
        filter.sortKey = .traffic
        // Largest first; equal traffic falls back to the name.
        #expect(filter.apply(to: [b, c, a]).map(\.id) == ["c", "a", "b"])
        filter.ascending = false
        #expect(filter.apply(to: [a, c, b]).map(\.id) == ["b", "a", "c"])
    }

    @Test func unknownLatencySortsLast() {
        var fast = Instance(id: "fast")
        fast.ping = 10
        var slow = Instance(id: "slow")
        slow.ping = 80
        let unknown = Instance(id: "unknown")

        var filter = InstanceFilter()
        filter.sortKey = .ping
        #expect(filter.apply(to: [unknown, slow, fast]).map(\.id) == ["fast", "slow", "unknown"])
    }

    @Test func trafficRateTrackerHandlesResets() {
        var tracker = TrafficRateTracker()
        let start = Date(timeIntervalSince1970: 1000)
        tracker.record(received: 0, transmitted: 0, at: start)
        tracker.record(received: 2000, transmitted: 1000, at: start.addingTimeInterval(2))
        #expect(tracker.latest?.received == 1000)
        #expect(tracker.latest?.transmitted == 500)
        tracker.record(received: 10, transmitted: 10, at: start.addingTimeInterval(4))
        #expect(tracker.latest?.received == 0)
    }
}
