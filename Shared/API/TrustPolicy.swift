//
//  TrustPolicy.swift
//  NodePass
//
//  URLSession delegate that optionally accepts self-signed server certificates.
//  NodePass masters started with `tls=1` present an auto-generated certificate, so
//  trusting it is the common case; the choice is still per master.
//

import Foundation

nonisolated final class TrustPolicyDelegate: NSObject, URLSessionDelegate, Sendable {
    let trustsSelfSignedCertificates: Bool

    init(trustsSelfSignedCertificates: Bool) {
        self.trustsSelfSignedCertificates = trustsSelfSignedCertificates
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard trustsSelfSignedCertificates,
              challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let trust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        completionHandler(.useCredential, URLCredential(trust: trust))
    }
}
