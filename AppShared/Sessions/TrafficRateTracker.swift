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

struct TrafficRateTracker: Equatable {
    private(set) var samples: [RateSample] = []
    private var lastDate: Date?
    private var lastReceived: UInt64?
    private var lastTransmitted: UInt64?
    let capacity: Int

    init(capacity: Int = 90) {
        self.capacity = capacity
    }

    /// Records a new cumulative reading and reports whether the tracker changed.
    ///
    /// Readings closer than a quarter second to the previous one are not sampled, and the
    /// previous reading is kept so the next sample measures the whole interval. Counter resets
    /// (values going down) produce a zero sample.
    @discardableResult
    mutating func record(received: UInt64, transmitted: UInt64, at date: Date = .now) -> Bool {
        guard let lastDate, let lastReceived, let lastTransmitted else {
            remember(received: received, transmitted: transmitted, at: date)
            return true
        }
        let elapsed = date.timeIntervalSince(lastDate)
        guard elapsed >= 0.25 else { return false }
        let rx = received >= lastReceived ? Double(received - lastReceived) / elapsed : 0
        let tx = transmitted >= lastTransmitted ? Double(transmitted - lastTransmitted) / elapsed : 0
        samples.append(RateSample(date: date, received: rx, transmitted: tx))
        if samples.count > capacity {
            samples.removeFirst(samples.count - capacity)
        }
        remember(received: received, transmitted: transmitted, at: date)
        return true
    }

    private mutating func remember(received: UInt64, transmitted: UInt64, at date: Date) {
        lastDate = date
        lastReceived = received
        lastTransmitted = transmitted
    }

    var latest: RateSample? { samples.last }

    var peakReceived: Double { samples.map(\.received).max() ?? 0 }
    var peakTransmitted: Double { samples.map(\.transmitted).max() ?? 0 }
    var peak: Double { max(peakReceived, peakTransmitted) }
}
