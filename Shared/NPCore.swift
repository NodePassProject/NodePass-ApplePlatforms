//
//  NPCore.swift
//  NodePass
//
//  Created by Junhui Lou on 6/28/25.
//

import Foundation

class NPCore {
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
    
    static func parseNPURLString(_ urlString: String) -> (scheme: String, tunnelHost: String, destinationHost: String, logLevel: String?, tlsLevel: String?)? {
        guard let schemeEndIndex = urlString.range(of: "://")?.lowerBound else {
            return nil
        }
        let scheme = String(urlString[..<schemeEndIndex])
        
        let afterScheme = urlString.suffix(from: urlString.index(schemeEndIndex, offsetBy: 3))
        guard let firstSlashIndex = afterScheme.firstIndex(of: "/") else {
            return nil
        }
        let tunnelHost = String(afterScheme[..<firstSlashIndex])
        
        let afterSlash = afterScheme.suffix(from: afterScheme.index(after: firstSlashIndex))
        guard let questionIndex = afterSlash.firstIndex(of: "?") else {
            return nil
        }
        let destinationHost = String(afterSlash[..<questionIndex])
        
        let queryString = String(afterSlash.suffix(from: afterSlash.index(after: questionIndex)))
        let queryItems = queryString.split(separator: "&").reduce(into: [String: String]()) { result, pair in
            let components = pair.split(separator: "=", maxSplits: 1).map(String.init)
            guard components.count == 2 else { return }
            result[components[0]] = components[1]
        }
        
        let logLevel = queryItems["log"]
        let tlsLevel = queryItems["tls"]
        
        return (scheme, tunnelHost, destinationHost, logLevel, tlsLevel)
    }
}
