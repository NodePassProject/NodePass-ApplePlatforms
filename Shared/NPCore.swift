//
//  NPCore.swift
//  NodePass
//
//  Created by Junhui Lou on 6/28/25.
//

import Foundation

class NPCore {
    // MARK: - Strings
    class Strings {
        static let NPServiceSortIndicator = "NPServiceSortIndicator"
        static let NPServiceSortOrder = "NPServiceSortOrder"
        static let NPServerSortIndicator = "NPServerSortIndicator"
        static let NPServerSortOrder = "NPServerSortOrder"
        static let NPAdvancedMode = "NPAdvancedMode"
        static let NPServerMetadataUpdatingRate = "NPServerMetadataUpdatingRate"
    }
    
    class Defaults {
        static let serverMetadataUpdatingRate: Double = 0.2
    }
    
    // MARK: - User Defaults
    static let userDefaults: UserDefaults = UserDefaults(suiteName: "group.com.argsment.NodePass")!
    
    static func registerUserDefaults() {
        let defaultValues: [String: Any] = [
            Strings.NPServiceSortIndicator: "date",
            Strings.NPServiceSortOrder: "ascending",
            Strings.NPServerSortIndicator: "date",
            Strings.NPServerSortOrder: "ascending",
            Strings.NPAdvancedMode: false,
            Strings.NPServerMetadataUpdatingRate: Defaults.serverMetadataUpdatingRate
        ]
        userDefaults.register(defaults: defaultValues)
    }
    
    static var isAdvancedModeEnabled: Bool {
        userDefaults.bool(forKey: NPCore.Strings.NPAdvancedMode)
    }
    
    static var serverMetadataUpdatingRate: Double {
        userDefaults.double(forKey: Strings.NPServerMetadataUpdatingRate)
    }
    
    // MARK: Command URL Process
    enum Scheme {
        case server
        case client
    }
    
    static func parseScheme(urlString: String) -> Scheme {
        if urlString.hasPrefix("server") {
            return .server
        }
        if urlString.hasPrefix("client") {
            return .client
        }
        fatalError()
    }
    
    static func parseAddressesAndPorts(urlString: String) -> (tunnel: (address: String, port: String), destination: (address: String, port: String)) {
        let urlString = urlString
        let schemePrefixes = ["server://", "client://"]
        var stringWithoutPrefix = ""
        for prefix in schemePrefixes {
            if urlString.hasPrefix(prefix) {
                stringWithoutPrefix = String(urlString.dropFirst(prefix.count))
                break
            }
        }
        
        var stringWithoutPrefixAndParameters = stringWithoutPrefix
        if let queryStartIndex = stringWithoutPrefix.firstIndex(of: "?") {
            stringWithoutPrefixAndParameters = String(stringWithoutPrefix[..<queryStartIndex])
        }
        
        let stringParts: (String, String)
        let slashIndex = stringWithoutPrefixAndParameters.firstIndex(of: "/")!
        let tunnalStringPart = String(stringWithoutPrefixAndParameters[..<slashIndex])
        let destinationStringPart = String(stringWithoutPrefixAndParameters[stringWithoutPrefixAndParameters.index(after: slashIndex)...])
        stringParts = (tunnalStringPart, destinationStringPart)
        
        func parseStringPart(_ part: String) -> (address: String, port: String) {
            let lastColonIndex = part.lastIndex(of: ":")!
            
            let address = String(part[..<lastColonIndex])
            let portStartIndex = part.index(after: lastColonIndex)
            let port = String(part[portStartIndex...])
            return (address, port)
        }
        
        return (
            tunnel: parseStringPart(stringParts.0),
            destination: parseStringPart(stringParts.1)
        )
    }
    
    static func parseQueryParameters(urlString: String, isFull: Bool = false) -> [String: String] {
        let queryString = extractQueryParameterString(urlString: urlString, isFull: isFull)
        let keyValuePairs = queryString.components(separatedBy: "&")
        var parameters = [String: String]()
        for pair in keyValuePairs {
            let components = pair.components(separatedBy: "=")
            
            guard components.count >= 1 else { continue }
            
            let key = components[0]
            let value = components.count >= 2 ? components[1] : ""
            
            parameters[key] = value
        }
        
        return parameters
    }
    
    static func extractSchemePrefix(urlString: String) -> String {
        let schemePrefixes = ["server://", "client://"]
        for prefix in schemePrefixes {
            if urlString.hasPrefix(prefix) {
                return prefix
            }
        }
        fatalError()
    }
    
    static func extractQueryParameterString(urlString: String, isFull: Bool = false) -> String {
        guard let questionMarkIndex = urlString.firstIndex(of: "?") else {
            return ""
        }
        return String(urlString[urlString.index(after: questionMarkIndex)...])
    }
    
    // MARK: - Utilities
    static func noEmptyName(_ name: String) -> String {
        return name == "" ? String(localized: "Untitled") : name
    }
    
    static func formatBytes(_ bytes: Int64, decimals: Int = 2) -> String {
        let units = ["B", "KB", "MB", "GB", "TB", "PB"]
        var value = Double(bytes)
        var unitIndex = 0
        
        while value >= 1024 && unitIndex < units.count - 1 {
            value /= 1000
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
    
    static func localizedTLSLevel(tlsLevel: String) -> String {
        switch(tlsLevel) {
        case "0":
            return String(localized: "Unencrypted", comment: "TLS Level: Unencrypted")
        case "1":
            return String(localized: "Self-signed Certificates", comment: "TLS Level: Self-signed Certificates")
        case "2":
            return String(localized: "Trusted Certificates", comment: "TLS Level: Trusted Certificates")
        default:
            return String(localized: "Unknown")
        }
    }
}
