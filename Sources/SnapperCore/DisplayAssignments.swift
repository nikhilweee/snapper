import Foundation

public enum LayoutChoice: Codable, Equatable, Sendable {
    case off
    case layout(String)

    private enum CodingKeys: String, CodingKey { case layoutId, off }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let off = try container.decodeIfPresent(Bool.self, forKey: .off) ?? false
        let id = try container.decodeIfPresent(String.self, forKey: .layoutId)
        switch (off, id) {
        case (true, nil): self = .off
        case (false, let id?): self = .layout(id)
        default:
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Choose off: true or a layoutId."))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .off: try container.encode(true, forKey: .off)
        case .layout(let id): try container.encode(id, forKey: .layoutId)
        }
    }
}

public final class AssignmentStore {
    private struct State: Codable {
        var version = 1
        var displays: [String: LayoutChoice] = [:]
    }

    public let url: URL
    private var state: State

    public init(url: URL) throws {
        self.url = url
        if FileManager.default.fileExists(atPath: url.path) {
            state = try JSONDecoder().decode(State.self, from: Data(contentsOf: url))
            guard state.version == 1 else { throw ConfigError.invalid("Unsupported state.json version.") }
        } else {
            state = State()
        }
    }

    public func savedChoice(for displayUUID: String) -> LayoutChoice? { state.displays[displayUUID] }

    public func set(_ choice: LayoutChoice, for displayUUID: String) throws {
        var replacement = state
        replacement.displays[displayUUID] = choice
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try ConfigurationStore.encoded(replacement).write(to: url, options: .atomic)
        state = replacement
    }

    public func effectiveChoice(for displayUUID: String?, configuration: Configuration) -> LayoutChoice {
        guard let displayUUID, let saved = savedChoice(for: displayUUID) else {
            return .layout(configuration.defaultLayoutId)
        }
        switch saved {
        case .off: return .off
        case .layout(let id):
            return .layout(configuration.layouts.contains { $0.id == id } ? id : configuration.defaultLayoutId)
        }
    }
}
