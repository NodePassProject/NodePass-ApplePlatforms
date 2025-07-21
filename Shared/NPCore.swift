//
//  NPCore.swift
//  NodePass
//
//  Created by Junhui Lou on 6/28/25.
//

import Foundation
import Cache

class NPCore {
    // MARK: - Cache
    static let serverMetadataCacheStorage = try! Storage<String, ServerMetadata>(
        diskConfig: DiskConfig(
            name: "NPServerMetadataCache",
            expiry: .never
        ),
        memoryConfig: MemoryConfig(),
        fileManager: FileManager(),
        transformer: TransformerFactory.forCodable(ofType: ServerMetadata.self)
    )
    
    // MARK: - Utilities
    static func noEmptyName(_ name: String) -> String {
        return name == "" ? String(localized: "Untitled") : name
    }
    
    static func formatBytes(_ bytes: Int, decimals: Int = 2) -> String {
        let units = ["B", "KB", "MB", "GB", "TB", "PB"]
        var value = Double(bytes)
        var unitIndex = 0
        
        while value >= 1024 && unitIndex < units.count - 1 {
            value /= 1024
            unitIndex += 1
        }
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = decimals
        formatter.roundingMode = .ceiling
        
        guard let formattedValue = formatter.string(from: NSNumber(value: value)) else {
            return ""
        }
        
        return "\(formattedValue) \(units[unitIndex])"
    }
    
    static func formatTimeInterval(seconds: Int64, shortened: Bool = false) -> String {
        let minutes = seconds / 60
        let hours = minutes / 60
        let days = hours / 24

        func formatShort(_ unit: String, _ value: Int64) -> String {
            return String(format: NSLocalizedString("%lld%@", comment: "Short format: 5d"), value, NSLocalizedString(unit, comment: "Time unit"))
        }

        func formatLong(_ unit1: String, _ value1: Int64, _ unit2: String, _ value2: Int64) -> String {
            return String(format: NSLocalizedString("%lld%@%lld%@", comment: "Long format: 5d 3h"), value1, NSLocalizedString(unit1, comment: "Time unit 1"), value2, NSLocalizedString(unit2, comment: "Time unit 2"))
        }
        
        if days >= 10 {
            return formatShort(String(localized: "timeUnitShortened.d"), days)
        } else if days > 0 {
            return shortened ? formatShort(String(localized: "timeUnitShortened.d"), days) : formatLong(String(localized: "timeUnitShortened.d"), days, String(localized: "timeUnitShortened.h"), hours % 24)
        } else if hours > 0 {
            return shortened ? formatShort(String(localized: "timeUnitShortened.h"), hours) : formatLong(String(localized: "timeUnitShortened.h"), hours, String(localized: "timeUnitShortened.m"), minutes % 60)
        } else if minutes > 0 {
            return shortened ? formatShort(String(localized: "timeUnitShortened.m"), minutes) : formatLong(String(localized: "timeUnitShortened.m"), minutes, String(localized: "timeUnitShortened.s"), seconds % 60)
        } else {
            return formatShort(String(localized: "timeUnitShortened.s"), seconds)
        }
    }
}
