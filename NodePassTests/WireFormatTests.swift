//
//  WireFormatTests.swift
//  NodePassTests
//

import Foundation
import Testing
@testable import NodePass

struct WireFormatTests {
    @Test func sseParserAssemblesEvents() {
        var parser = ServerSentEventParser()
        #expect(parser.feed(line: "retry: 3000") == nil)
        #expect(parser.feed(line: "") == nil)
        #expect(parser.feed(line: ": keep-alive") == nil)
        #expect(parser.feed(line: "event: instance") == nil)
        #expect(parser.feed(line: "data: {\"a\":1,") == nil)
        #expect(parser.feed(line: "data: \"b\":2}\r") == nil)
        let event = parser.feed(line: "")
        #expect(event?.event == "instance")
        #expect(event?.data == "{\"a\":1,\n\"b\":2}")
        #expect(event?.retry == 3000)
    }

    @Test func decodesInstanceEventWithGoTimestamp() throws {
        let json = """
        {"type":"update","time":"2026-10-31T12:34:56.123456789+08:00","instance":{"id":"a1b2c3d4","alias":"edge","type":"server","status":"running","url":"server://:10101/:8080","config":"server://:10101/:8080?log=info","restart":true,"meta":{"peer":{"sid":"","type":"","alias":""},"tags":{"env":"prod"}},"mode":1,"ping":12,"pool":64,"tcps":3,"udps":0,"tcprx":1024,"tcptx":2048,"udprx":0,"udptx":0},"logs":""}
        """
        let event = try JSONDecoder().decode(InstanceEvent.self, from: Data(json.utf8))
        #expect(event.kind == .update)
        let instance = try #require(event.instance)
        #expect(instance.role == .server)
        #expect(instance.status == .running)
        #expect(instance.meta.tags["env"] == "prod")
        #expect(instance.totalReceived == 1024)
        let components = Calendar(identifier: .gregorian).dateComponents(in: TimeZone(secondsFromGMT: 8 * 3600)!, from: event.time)
        #expect(components.hour == 12)
        #expect(components.minute == 34)
        #expect(components.second == 56)
    }

    @Test func decodesPartialInstanceLeniently() throws {
        let json = #"{"id":"********","url":"key","config":"1a2b3c4d5e6f7890","meta":{"peer":{},"tags":null}}"#
        let instance = try JSONDecoder().decode(Instance.self, from: Data(json.utf8))
        #expect(instance.isAPIKeyHolder)
        #expect(instance.meta.tags.isEmpty)
        #expect(instance.status == .other(""))
    }

    @Test func decodesMasterInfo() throws {
        let json = #"{"mid":"1a2b3c4d5e6f7890","alias":"edge","os":"linux","arch":"amd64","noc":4,"cpu":37,"mem_total":8000,"mem_used":4000,"swap_total":0,"swap_used":0,"netrx":10,"nettx":20,"diskr":1,"diskw":2,"sysup":100,"ver":"1.9.0","name":"host","uptime":50,"log":"info","tls":"1","crt":"","key":""}"#
        let info = try JSONDecoder().decode(MasterInfo.self, from: Data(json.utf8))
        #expect(info.masterID == "1a2b3c4d5e6f7890")
        #expect(info.cpuCount == 4)
        #expect(info.memoryRatio == 0.5)
        #expect(info.hasSystemMetrics)
        #expect(info.tlsModeTitle == "Self-signed certificate")
    }

    @Test func patchEncodesOnlyProvidedFields() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(InstancePatch(action: .restart, restart: false))
        #expect(String(decoding: data, as: UTF8.self) == #"{"action":"restart","restart":false}"#)
        let meta = try encoder.encode(InstancePatch(meta: .init(tags: ["a": "b"])))
        #expect(String(decoding: meta, as: UTF8.self) == #"{"meta":{"tags":{"a":"b"}}}"#)
    }

    @Test func normalizesBaseURL() {
        #expect(MasterCredentials.normalizeBaseURL(" https://h:9090/api/v1/ ")?.absoluteString == "https://h:9090/api/v1")
        #expect(MasterCredentials.normalizeBaseURL("ftp://h/api") == nil)
        #expect(MasterCredentials.normalizeBaseURL("https:///api") == nil)
    }

    @Test func deepLinkImport() throws {
        let url = Data("https://h:9090/api/v1".utf8).base64EncodedString()
        let key = Data("secret".utf8).base64EncodedString()
        let link = try #require(URL(string: "np://master?url=\(url)&key=\(key)"))
        let imported = try #require(MasterImport(deepLink: link))
        #expect(imported.url == "https://h:9090/api/v1")
        #expect(imported.key == "secret")
        #expect(MasterImport(deepLink: try #require(URL(string: "np://master?id=abc"))) == nil)
    }
}
