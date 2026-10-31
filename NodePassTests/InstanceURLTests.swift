//
//  InstanceURLTests.swift
//  NodePassTests
//

import Foundation
import Testing
@testable import NodePass

struct InstanceURLTests {
    @Test func parsesNodePassServer() throws {
        let url = try InstanceURL(parsing: "server://0.0.0.0:10101/127.0.0.1:8080?tls=1&mode=2&log=info")
        #expect(url.role == .server)
        #expect(url.credential == nil)
        #expect(url.tunnel.host == "0.0.0.0")
        #expect(url.tunnel.port == 10101)
        #expect(url.targets.count == 1)
        #expect(url.targets[0].host == "127.0.0.1")
        #expect(url.targets[0].port == 8080)
        #expect(url.parameters.map(\.key) == ["tls", "mode", "log"])
        #expect(url[parameter: "mode"] == "2")
    }

    @Test func roundTripsPreservingOrder() throws {
        let text = "client://secret@relay.example.com:10101/127.0.0.1:3306?min=32&read=30s&log=debug"
        let url = try InstanceURL(parsing: text)
        #expect(url.string == text)
    }

    @Test func parsesEmptyHostsAndMultipleTargets() throws {
        let url = try InstanceURL(parsing: "server://:10101/:8080,backup.local:8081?mode=2&lbs=2")
        #expect(url.tunnel.host.isEmpty)
        #expect(url.tunnel.port == 10101)
        #expect(url.targets.count == 2)
        #expect(url.targets[0].host.isEmpty)
        #expect(url.targets[1].host == "backup.local")
        #expect(url.targets[1].port == 8081)
        #expect(url.hasMultipleTargets)
        #expect(url.string == "server://:10101/:8080,backup.local:8081?mode=2&lbs=2")
    }

    @Test func parsesIPv6() throws {
        let url = try InstanceURL(parsing: "client://[2001:db8::1]:10101/[::1]:8080")
        #expect(url.tunnel.host == "2001:db8::1")
        #expect(url.tunnel.port == 10101)
        #expect(url.targets[0].host == "::1")
        #expect(url.string == "client://[2001:db8::1]:10101/[::1]:8080")
    }

    @Test func parsesNowherePortalWithCarriers() throws {
        let url = try InstanceURL(parsing: "portal://0123456789abcdef0123456789abcdef@*/tcp4:2000/udp6:2001?out=egress")
        #expect(url.role == .portal)
        #expect(url.flavor == .openCtrl)
        #expect(url.credential == "0123456789abcdef0123456789abcdef")
        #expect(url.tunnel.host == "*")
        #expect(url.tunnel.port == nil)
        #expect(url.carriers.count == 2)
        #expect(url.carriers[0].kind == .tcp4)
        #expect(url.carriers[1].port == 2001)
        #expect(url.string == "portal://0123456789abcdef0123456789abcdef@*/tcp4:2000/udp6:2001?out=egress")
    }

    @Test func parsesVector() throws {
        let url = try InstanceURL(parsing: "vector://0123456789abcdef0123456789abcdef@portal.example:2000?pin=none&in=127.0.0.1:1080")
        #expect(url.role == .vector)
        #expect(url.tunnel.port == 2000)
        #expect(url[parameter: "in"] == "127.0.0.1:1080")
        #expect(url.validate().filter { $0.severity == .error }.isEmpty)
    }

    @Test func decodesPercentEncodingAndPlus() throws {
        let url = try InstanceURL(parsing: "server://p%40ss@host:1/t:2?crt=%2Fetc%2Fcert.pem&note=a+b")
        #expect(url.credential == "p@ss")
        #expect(url[parameter: "crt"] == "/etc/cert.pem")
        #expect(url[parameter: "note"] == "a b")
        #expect(url.string.contains("p%40ss@"))
        #expect(url.string.contains("crt=/etc/cert.pem"))
    }

    @Test func subscriptSetsRemovesAndAppends() throws {
        var url = try InstanceURL(parsing: "server://:1/:2?tls=1")
        url[parameter: "tls"] = "2"
        url[parameter: "crt"] = "/c.pem"
        #expect(url.parameters.map(\.key) == ["tls", "crt"])
        url[parameter: "tls"] = nil
        #expect(url.parameters.map(\.key) == ["crt"])
        #expect(!url.hasParameter("tls"))
    }

    @Test func rejectsMalformedInput() {
        #expect(throws: InstanceURLError.self) { try InstanceURL(parsing: "") }
        #expect(throws: InstanceURLError.self) { try InstanceURL(parsing: "no scheme here") }
        #expect(throws: InstanceURLError.self) { try InstanceURL(parsing: "server://") }
    }

    @Test func unknownSchemeStillParses() throws {
        let url = try InstanceURL(parsing: "tunnel://a:1/b:2")
        #expect(url.role == .other("tunnel"))
        #expect(url.flavor == nil)
        #expect(url.validate().contains { $0.field == .role })
    }

    @Test func validationFlagsMissingPorts() throws {
        let url = try InstanceURL(parsing: "server://0.0.0.0/127.0.0.1")
        let errors = url.validate().filter { $0.severity == .error }
        #expect(errors.contains { $0.field == .tunnel })
        #expect(errors.contains { $0.field == .target(0) })
    }

    @Test func validationWarnsAboutTLSRequirementAndDuplicates() throws {
        let url = try InstanceURL(parsing: "server://:1/:2?type=1&log=x&log=info")
        let issues = url.validate()
        #expect(issues.contains { $0.field == .parameter("type") && $0.severity == .warning })
        #expect(issues.contains { $0.message.contains("appears more than once") })
        #expect(issues.contains { $0.field == .parameter("log") && $0.severity == .error })
    }

    @Test func validationNowhereRules() throws {
        let badKey = try InstanceURL(parsing: "portal://short@*:2000")
        #expect(badKey.validate().contains { $0.field == .credential && $0.severity == .error })

        let conflict = try InstanceURL(parsing: "portal://0123456789abcdef0123456789abcdef@*:2000?out=egress&dial=10.0.0.1")
        #expect(conflict.validate().contains { $0.field == .parameter("dial") })

        let vectorNoIngress = try InstanceURL(parsing: "vector://0123456789abcdef0123456789abcdef@host:2000")
        #expect(vectorNoIngress.validate().contains { $0.field == .parameter("in") && $0.severity == .error })

        let twoCarriers = try InstanceURL(parsing: "egress://0123456789abcdef0123456789abcdef@host/tcp:1/udp:2")
        #expect(twoCarriers.validate().contains { $0.field == .carriers })
    }

    @Test func hostPortParsing() {
        #expect(HostPort(parsing: "example.com:443").port == 443)
        #expect(HostPort(parsing: ":443").host.isEmpty)
        #expect(HostPort(parsing: "example.com").port == nil)
        #expect(HostPort(parsing: "[::1]:80").host == "::1")
        #expect(HostPort(parsing: "fe80::1").host == "fe80::1")
        #expect(HostPort(host: "fe80::1", port: 1).description == "[fe80::1]:1")
        #expect(HostPort(parsing: "*:2000").host == "*")
    }
}
