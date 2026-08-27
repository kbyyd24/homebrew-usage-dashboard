import Foundation

public enum ProviderType: String, Hashable, Sendable, Codable {
    case kimi
    case minimax
    case deepseek
    case custom
}

public struct CustomQueryConfig: Hashable, Sendable, Codable {
    public let url: String
    public let method: String
    public let headers: [String: String]
    public let body: String?
    public let extractor: String

    public init(
        url: String,
        method: String = "GET",
        headers: [String: String] = [:],
        body: String? = nil,
        extractor: String
    ) {
        self.url = url
        self.method = method
        self.headers = headers
        self.body = body
        self.extractor = extractor
    }
}

public struct ProviderConfig: Hashable, Sendable, Codable {
    public let id: String
    public let type: ProviderType
    public let name: String
    public let apiKeyEnv: String?
    public let apiKey: String?
    public let refreshIntervalSec: Int?
    public let custom: CustomQueryConfig?

    public init(
        id: String,
        type: ProviderType,
        name: String,
        apiKeyEnv: String? = nil,
        apiKey: String? = nil,
        refreshIntervalSec: Int? = nil,
        custom: CustomQueryConfig? = nil
    ) {
        self.id = id
        self.type = type
        self.name = name
        self.apiKeyEnv = apiKeyEnv
        self.apiKey = apiKey
        self.refreshIntervalSec = refreshIntervalSec
        self.custom = custom
    }
}

public struct AppConfig: Hashable, Sendable, Codable {
    public let defaultIntervalSec: Int
    public let providers: [ProviderConfig]
    /// Runtime-derived warnings for providers that could not be configured.
    public let warnings: [String]

    public init(defaultIntervalSec: Int = 600, providers: [ProviderConfig], warnings: [String] = []) {
        self.defaultIntervalSec = defaultIntervalSec
        self.providers = providers
        self.warnings = warnings
    }

    // `warnings` is derived at load time and is not part of the persisted config.
    private enum CodingKeys: String, CodingKey {
        case defaultIntervalSec, providers
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        defaultIntervalSec = try container.decodeIfPresent(Int.self, forKey: .defaultIntervalSec) ?? 600
        providers = try container.decode([ProviderConfig].self, forKey: .providers)
        warnings = []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(defaultIntervalSec, forKey: .defaultIntervalSec)
        try container.encode(providers, forKey: .providers)
    }
}
