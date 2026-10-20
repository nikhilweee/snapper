import Foundation

public struct Zone: Codable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(id: String, name: String, x: Double, y: Double, width: Double, height: Double) {
        self.id = id
        self.name = name
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public struct Layout: Codable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let zones: [Zone]

    public init(id: String, name: String, zones: [Zone]) {
        self.id = id
        self.name = name
        self.zones = zones
    }
}

public struct Configuration: Codable, Equatable, Sendable {
    public let version: Int
    public let defaultLayoutId: String
    public let layouts: [Layout]

    public init(version: Int = 1, defaultLayoutId: String, layouts: [Layout]) {
        self.version = version
        self.defaultLayoutId = defaultLayoutId
        self.layouts = layouts
    }

    public func validated() throws -> Configuration {
        guard version == 1 else { throw ConfigError.invalid("Unsupported version \(version); expected 1.") }
        guard !layouts.isEmpty else { throw ConfigError.invalid("Add at least one layout.") }
        var layoutIDs = Set<String>()
        for layout in layouts {
            guard !layout.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !layout.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  layoutIDs.insert(layout.id).inserted else {
                throw ConfigError.invalid("Layout IDs must be nonempty and unique; each layout needs a name.")
            }
            guard !layout.zones.isEmpty else { throw ConfigError.invalid("Layout '\(layout.id)' needs at least one zone.") }
            var zoneIDs = Set<String>()
            for zone in layout.zones {
                guard !zone.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      zoneIDs.insert(zone.id).inserted else {
                    throw ConfigError.invalid("Zone IDs in '\(layout.id)' must be nonempty and unique.")
                }
                guard !zone.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    throw ConfigError.invalid("Zone '\(zone.id)' in '\(layout.id)' needs a nonempty name.")
                }
                guard [zone.x, zone.y, zone.width, zone.height].allSatisfy(\.isFinite),
                      zone.x >= 0, zone.y >= 0, zone.width > 0, zone.height > 0,
                      zone.x + zone.width <= 100, zone.y + zone.height <= 100 else {
                    throw ConfigError.invalid("Zone '\(zone.id)' in '\(layout.id)' must fit within 0–100%, with positive dimensions.")
                }
            }
        }
        guard layoutIDs.contains(defaultLayoutId) else {
            throw ConfigError.invalid("defaultLayoutId '\(defaultLayoutId)' does not match a layout.")
        }
        return self
    }

    public static let starter = Configuration(defaultLayoutId: "halves", layouts: [
        Layout(id: "halves", name: "Two Columns", zones: [
            Zone(id: "left", name: "Left", x: 0, y: 0, width: 50, height: 100),
            Zone(id: "right", name: "Right", x: 50, y: 0, width: 50, height: 100)
        ]),
        Layout(id: "thirds", name: "Three Columns", zones: [
            Zone(id: "left", name: "Left", x: 0, y: 0, width: 33, height: 100),
            Zone(id: "center", name: "Center", x: 33, y: 0, width: 34, height: 100),
            Zone(id: "right", name: "Right", x: 67, y: 0, width: 33, height: 100)
        ])
    ])
}

public enum ConfigError: LocalizedError {
    case invalid(String)
    public var errorDescription: String? {
        switch self { case .invalid(let message): return message }
    }
}

public final class ConfigurationStore {
    public let url: URL
    public private(set) var current: Configuration

    public init(url: URL) throws {
        self.url = url
        self.current = .starter
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: url.path) {
            try Self.encoded(Configuration.starter).write(to: url, options: .atomic)
        }
        try reload()
    }

    public func reload() throws {
        // Decode and validate before replacing the active configuration.
        let replacement = try JSONDecoder().decode(Configuration.self, from: Data(contentsOf: url)).validated()
        current = replacement
    }

    public static func encoded<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(value)
    }
}
