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
            expiry: .date(Date().addingTimeInterval(7*24*3600))
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
}
