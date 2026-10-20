import Foundation
import Testing
import SnapperCore

struct AssignmentTests {
    @Test func testHomeWorkRoundTripAndRestart() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("state.json")
        let store = try AssignmentStore(url: url)
        try store.set(.layout("halves"), for: "home-uuid")
        try store.set(.layout("thirds"), for: "work-uuid")
        // Connection order and screen coordinates are deliberately absent from the API.
        for id in ["work-uuid", "home-uuid", "work-uuid", "home-uuid"] {
            let restarted = try AssignmentStore(url: url)
            #expect(restarted.effectiveChoice(for: id, configuration: .starter) == .layout(id == "home-uuid" ? "halves" : "thirds"))
        }
    }

    @Test func testOffPersistsAndUnknownDisplayUsesDefault() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("state.json")
        let store = try AssignmentStore(url: url)
        #expect(store.effectiveChoice(for: "new", configuration: .starter) == .layout("halves"))
        #expect(store.effectiveChoice(for: nil, configuration: .starter) == .layout("halves"))
        try store.set(.off, for: "home")
        #expect(try AssignmentStore(url: url).effectiveChoice(for: "home", configuration: .starter) == .off)
    }

    @Test func testMissingLayoutFallsBackWithoutLosingAssignment() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try AssignmentStore(url: directory.appendingPathComponent("state.json"))
        try store.set(.layout("custom"), for: "home")
        #expect(store.effectiveChoice(for: "home", configuration: .starter) == .layout("halves"))
        #expect(store.savedChoice(for: "home") == .layout("custom"))
        let restored = Configuration(defaultLayoutId: "halves", layouts: Configuration.starter.layouts + [Layout(id: "custom", name: "Custom", zones: Configuration.starter.layouts[0].zones)])
        #expect(store.effectiveChoice(for: "home", configuration: restored) == .layout("custom"))
    }

    @Test func testFailedSaveRetainsInMemoryAssignment() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try AssignmentStore(url: directory.appendingPathComponent("state.json"))
        try store.set(.layout("halves"), for: "home")
        try FileManager.default.removeItem(at: directory)
        // Replace the parent directory with a file to force an atomic-save failure.
        try Data().write(to: directory)
        #expect(throws: (any Error).self) { try store.set(.off, for: "home") }
        #expect(store.savedChoice(for: "home") == .layout("halves"))
    }

    @Test func testRejectsAmbiguousStateChoice() throws {
        let data = Data(#"{"off":true,"layoutId":"halves"}"#.utf8)
        #expect(throws: (any Error).self) { try JSONDecoder().decode(LayoutChoice.self, from: data) }
    }
}
