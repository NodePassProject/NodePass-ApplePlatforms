//
//  NodePassIntentError.swift
//  NodePass
//
//  Failures an intent reports back to Siri and Shortcuts, worded for people rather than logs.
//

import AppIntents
import Foundation

nonisolated enum NodePassIntentError: Error, CustomLocalizedStringResourceConvertible {
    case masterNotFound
    case instanceNotFound
    case invalidMasterURL(master: String)
    case masterUnreachable(master: String, reason: String)
    case masterRejected(master: String, reason: String)
    case invalidInstanceURL(reason: String)
    case flavorMismatch(role: String, master: String, flavor: String)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .masterNotFound:
            "This master is no longer saved in NodePass."
        case .instanceNotFound:
            "This instance no longer exists on its master."
        case .invalidMasterURL(let master):
            "The API URL saved for \(master) is not valid."
        case .masterUnreachable(let master, let reason):
            "\(master) is unreachable: \(reason)"
        case .masterRejected(let master, let reason):
            "\(master) rejected the request: \(reason)"
        case .invalidInstanceURL(let reason):
            "The instance URL is not valid: \(reason)"
        case .flavorMismatch(let role, let master, let flavor):
            "\(role) instances cannot run on \(master), which is a \(flavor) master."
        }
    }

    /// The error an intent surfaces for a failed call to `master`.
    static func wrap(_ error: any Error, master: MasterSnapshot) -> NodePassIntentError {
        if let intentError = error as? NodePassIntentError { return intentError }
        let apiError = APIError.wrap(error)
        switch apiError {
        case .notFound:
            return .instanceNotFound
        case .badRequest, .conflict, .forbidden:
            return .masterRejected(master: master.name, reason: apiError.localizedDescription)
        case .invalidBaseURL:
            return .invalidMasterURL(master: master.name)
        default:
            return .masterUnreachable(master: master.name, reason: apiError.localizedDescription)
        }
    }
}
