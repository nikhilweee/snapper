import Foundation
import Testing
import SnapperCore

struct ConfigurationTests {
    @Test func testStarterAndJSONRoundTrip() throws {
        let configuration = try Configuration.starter.validated()
        #expect(try JSONDecoder().decode(Configuration.self, from: ConfigurationStore.encoded(configuration)) == configuration)
    }

    @Test func testZoneNameIsIndependentFromIDAndRoundTrips() throws {
        let data = Data(#"{"id":"left","name":"Editor","x":0,"y":0,"width":50,"height":100}"#.utf8)
        let zone = try JSONDecoder().decode(Zone.self, from: data)
        #expect(zone.id == "left")
        #expect(zone.name == "Editor")
        let encoded = try ConfigurationStore.encoded(zone)
        #expect(try JSONDecoder().decode(Zone.self, from: encoded) == zone)
        let object = try JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        #expect(object?["name"] as? String == "Editor")
    }

    @Test func testMissingZoneNameIsRejectedWithoutReplacingActiveConfiguration() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("config.json")
        let store = try ConfigurationStore(url: url)
        let original = store.current
        let invalid = Data(#"{"version":1,"defaultLayoutId":"work","layouts":[{"id":"work","name":"Work","zones":[{"id":"editor","x":0,"y":0,"width":100,"height":100}]}]}"#.utf8)
        try invalid.write(to: url)
        #expect(throws: DecodingError.self) { try store.reload() }
        #expect(store.current == original)
        #expect(try Data(contentsOf: url) == invalid)
    }

    @Test func testBlankZoneNamesAreRejectedAndDuplicateNamesAreAllowed() throws {
        let invalid = Layout(id: "work", name: "Work", zones: [
            Zone(id: "left", name: " \n\t", x: 0, y: 0, width: 50, height: 100)
        ])
        #expect(throws: (any Error).self) { try Configuration(defaultLayoutId: "work", layouts: [invalid]).validated() }
        let valid = Layout(id: "work", name: "Work", zones: [
            Zone(id: "left", name: "Editor", x: 0, y: 0, width: 50, height: 100),
            Zone(id: "right", name: "Editor", x: 50, y: 0, width: 50, height: 100)
        ])
        _ = try Configuration(defaultLayoutId: "work", layouts: [valid]).validated()
    }

    @Test func testRejectsMalformedDefinitions() throws {
        let valid = Configuration.starter.layouts[0]
        let badZones = [
            Zone(id: "bad", name: "Invalid", x: -1, y: 0, width: 50, height: 100),
            Zone(id: "bad", name: "Invalid", x: 0, y: 0, width: 0, height: 100),
            Zone(id: "bad", name: "Invalid", x: 90, y: 0, width: 20, height: 100),
            Zone(id: "bad", name: "Invalid", x: 0, y: 99, width: 50, height: 2),
            Zone(id: "bad", name: "Invalid", x: .nan, y: 0, width: 50, height: 100),
            Zone(id: "", name: "Invalid", x: 0, y: 0, width: 50, height: 100)
        ]
        for zone in badZones {
            #expect(throws: (any Error).self) { try Configuration(defaultLayoutId: "test", layouts: [Layout(id: "test", name: "Test", zones: [zone])]).validated() }
        }
        #expect(throws: (any Error).self) { try Configuration(version: 2, defaultLayoutId: valid.id, layouts: [valid]).validated() }
        #expect(throws: (any Error).self) { try Configuration(defaultLayoutId: "missing", layouts: [valid]).validated() }
        #expect(throws: (any Error).self) { try Configuration(defaultLayoutId: valid.id, layouts: [valid, valid]).validated() }
        #expect(throws: (any Error).self) { try Configuration(defaultLayoutId: "empty", layouts: [Layout(id: "empty", name: "Empty", zones: [])]).validated() }
        #expect(throws: (any Error).self) { try Configuration(defaultLayoutId: "duplicate", layouts: [Layout(id: "duplicate", name: "Duplicate", zones: [valid.zones[0], valid.zones[0]])]).validated() }
    }

    @Test func testFirstLaunchCreatesStarterAndFailedReloadRetainsCurrent() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("config.json")
        let store = try ConfigurationStore(url: url)
        #expect(FileManager.default.fileExists(atPath: url.path))
        let original = store.current
        try Data("{broken".utf8).write(to: url)
        #expect(throws: (any Error).self) { try store.reload() }
        #expect(store.current == original)
        let invalid = Configuration(defaultLayoutId: "missing", layouts: original.layouts)
        try ConfigurationStore.encoded(invalid).write(to: url)
        #expect(throws: (any Error).self) { try store.reload() }
        #expect(store.current == original)
        let replacement = Configuration(defaultLayoutId: "thirds", layouts: original.layouts)
        try ConfigurationStore.encoded(replacement).write(to: url)
        try store.reload()
        #expect(store.current == replacement)
    }

    @Test func testInvalidExistingFileIsNeverOverwritten() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("config.json")
        let invalid = Data("not JSON".utf8)
        try invalid.write(to: url)
        #expect(throws: (any Error).self) { try ConfigurationStore(url: url) }
        #expect(try Data(contentsOf: url) == invalid)
    }
}

func temporaryDirectory() -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent("snapper-tests-\(UUID().uuidString)", isDirectory: true)
}
