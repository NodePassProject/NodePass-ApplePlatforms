//
//  UnsafeURLSession.swift
//  NodePass
//
//  Created by Junhui Lou on 6/29/25.
//

import Foundation

class UnsafeSSLURLSession {
    static func create() -> URLSession {
        let configuration = URLSessionConfiguration.default
        
        return URLSession(
            configuration: configuration,
            delegate: UnsafeSSLDelegate(),
            delegateQueue: nil
        )
    }
}

class UnsafeSSLDelegate: NSObject, URLSessionDelegate {
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        if let serverTrust = challenge.protectionSpace.serverTrust {
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}
