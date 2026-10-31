//
//  NavigationModelTests.swift
//  NodePassTests
//

import Foundation
import Testing
@testable import NodePass

@MainActor
struct NavigationModelTests {
    @Test func switchingMastersClearsTheInstanceSelection() {
        let model = NavigationModel()
        model.select(instance: "i1", on: "m1")
        #expect(model.sidebarSelection == .master("m1"))
        #expect(model.selectedInstanceIDs == ["i1"])

        model.sidebarSelection = .master("m1")
        #expect(model.selectedInstanceIDs == ["i1"])

        model.sidebarSelection = .master("m2")
        #expect(model.selectedInstanceIDs.isEmpty)
    }

    @Test func singleSelectionBridgesToTheSet() {
        let model = NavigationModel()
        model.selectedInstanceID = "a"
        #expect(model.selectedInstanceIDs == ["a"])

        model.selectedInstanceIDs = ["a", "b"]
        #expect(model.selectedInstanceID == nil)

        model.selectedInstanceID = nil
        #expect(model.selectedInstanceIDs.isEmpty)
    }

    @Test func deepLinksImportOrSelect() throws {
        let model = NavigationModel()
        model.handle(deepLink: DeepLink.master("m7"))
        #expect(model.sidebarSelection == .master("m7"))

        model.handle(deepLink: DeepLink.master("m8", instance: "i3"))
        #expect(model.sidebarSelection == .master("m8"))
        #expect(model.selectedInstanceIDs == ["i3"])

        let encodedURL = Data("http://127.0.0.1:9090/api/v1".utf8).base64EncodedString()
        let encodedKey = Data("demo".utf8).base64EncodedString()
        model.handle(deepLink: try #require(URL(string: "np://master?url=\(encodedURL)&key=\(encodedKey)")))
        #expect(model.pendingImport?.url == "http://127.0.0.1:9090/api/v1")
        #expect(model.pendingImport?.key == "demo")
    }

    @Test func sidebarItemsRoundTripForWindowRestoration() throws {
        for item in [SidebarItem.master("m1"), .tool(.apiConsole)] {
            let data = try JSONEncoder().encode(item)
            #expect(try JSONDecoder().decode(SidebarItem.self, from: data) == item)
        }
    }

    #if os(macOS)
    @Test func tableSortOrderRoundTrips() throws {
        for key in InstanceSortKey.allCases {
            for ascending in [true, false] {
                let choice = try #require(InstanceSortKey.from(key.comparator(ascending: ascending)))
                #expect(choice.key == key)
                #expect(choice.ascending == ascending)
            }
        }
        // Traffic lists the largest first when "ascending", which a header shows as descending.
        #expect(InstanceSortKey.traffic.comparator(ascending: true).order == .reverse)
        #expect(InstanceSortKey.name.comparator(ascending: true).order == .forward)
    }
    #endif
}
