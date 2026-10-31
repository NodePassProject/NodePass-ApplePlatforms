//
//  ParameterCatalogTests.swift
//  NodePassTests
//

import Foundation
import Testing
@testable import NodePass

struct ParameterCatalogTests {
    @Test func durationValidation() {
        #expect(ParameterSpec.isValidDuration("5m"))
        #expect(ParameterSpec.isValidDuration("1h30m"))
        #expect(ParameterSpec.isValidDuration("0"))
        #expect(ParameterSpec.isValidDuration("250ms"))
        #expect(!ParameterSpec.isValidDuration("5"))
        #expect(!ParameterSpec.isValidDuration("5 m"))
        #expect(!ParameterSpec.isValidDuration("m"))
        #expect(!ParameterSpec.isValidDuration("5x"))
    }

    @Test func specLookupHonorsRole() throws {
        let serverMode = try #require(ParameterCatalog.spec(key: "mode", role: .server))
        let clientMode = try #require(ParameterCatalog.spec(key: "mode", role: .client))
        #expect(serverMode.displayValue("1") == "Reverse")
        #expect(clientMode.displayValue("1") == "Single-end")
        #expect(ParameterCatalog.spec(key: "min", role: .server) == nil)
        #expect(ParameterCatalog.spec(key: "min", flavor: .nodePass) != nil)
        #expect(ParameterCatalog.spec(key: "in", role: .vector) != nil)
        #expect(ParameterCatalog.spec(key: "in", role: .portal) == nil)
    }

    @Test func validationByKind() throws {
        let tls = try #require(ParameterCatalog.spec(key: "tls", role: .server))
        #expect(tls.validate("1") == nil)
        #expect(tls.validate("3") != nil)

        let rate = try #require(ParameterCatalog.spec(key: "rate", role: .client))
        #expect(rate.validate("100") == nil)
        #expect(rate.validate("-1") != nil)
        #expect(rate.validate("fast") != nil)

        let block = try #require(ParameterCatalog.spec(key: "block", role: .server))
        #expect(block.validate("12") == nil)
        #expect(block.validate("0") == nil)
        #expect(block.validate("4") != nil)
        #expect(block.displayValue("31") == "SOCKS, TLS")

        let pin = try #require(ParameterCatalog.spec(key: "pin", role: .vector))
        #expect(pin.validate(String(repeating: "a", count: 64)) == nil)
        #expect(pin.validate("none") == nil)
        #expect(pin.validate("ABC") != nil)

        let ingress = try #require(ParameterCatalog.spec(key: "in", role: .vector))
        #expect(ingress.validate("127.0.0.1:1080") == nil)
        #expect(ingress.validate("user:pass@127.0.0.1:1080") == nil)
        #expect(ingress.validate("127.0.0.1") != nil)
    }

    @Test func everySpecHasValidDefault() {
        for flavor in MasterFlavor.allCases {
            for spec in ParameterCatalog.specs(for: flavor) {
                if let defaultValue = spec.defaultValue {
                    #expect(spec.validate(defaultValue) == nil, "\(spec.key) default \(defaultValue) must validate")
                }
            }
        }
    }

    @Test func flavorInference() throws {
        #expect(MasterFlavor.infer(fromBaseURL: try #require(URL(string: "https://h:9090/api/v1"))) == .nodePass)
        #expect(MasterFlavor.infer(fromBaseURL: try #require(URL(string: "http://h/control/v2"))) == .openCtrl)
        #expect(MasterFlavor.infer(fromBaseURL: try #require(URL(string: "http://h/api"))) == nil)
        #expect(MasterFlavor.infer(fromRoles: [InstanceRole.other("x"), .vector]) == .openCtrl)
    }
}
