//
//  TrafficRateTracker.swift
//  NodePass
//
//  Turns cumulative byte counters into per-second throughput samples for sparklines.
//

import Foundation

struct RateSample: Hashable, Identifiable {
    let date: Date
    /// Bytes per second.
    let received: Double
    let transmitted: Double

    var id: Date { date }
}

struct TrafficRateTracker {
    private(set) var samples: [RateSample] = []
    private var lastDate: Date?
    private var lastReceived: UInt64?
    private var lastTransmitted: UInt64?
    let capacity: Int

    init(capacity: Int = 90) {
        self.capacity = capacity
    }

    /// Records a new cumulative reading. Counter resets (values going down) produce a zero sample.
    mutating func record(received: UInt64, transmitted: UInt64, at date: Date = .now) {
        defer {
            lastDate = date
            lastReceived = received
            lastTransmitted = transmitted
        }
        guard let lastDate, let lastReceived, let lastTransmitted else { return }
        let elapsed = date.timeIntervalSince(lastDate)
        guard elapsed >= 0.25 else { return }
        let rx = received >= lastReceived ? Double(received - lastReceived) / elapsed : 0
        let tx = transmitted >= lastTransmitted ? Double(transmitted - lastTransmitted) / elapsed : 0
        samples.append(RateSample(date: date, received: rx, transmitted: tx))
        if samples.count > capacity {
            samples.removeFirst(samples.count - capacity)
        }
    }

    var latest: RateSample? { samples.last }

    var peakReceived: Double { samples.map(\.received).max() ?? 0 }
    var peakTransmitted: Double { samples.map(\.transmitted).max() ?? 0 }
    var peak: Double { max(peakReceived, peakTransmitted) }
}
