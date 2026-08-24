import Foundation

public enum ProviderType: String, Hashable, Sendable, Codable {
    case kimi
    case minimax
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

    public init(defaultIntervalSec: Int = 600, providers: [ProviderConfig]) {
        self.defaultIntervalSec = defaultIntervalSec
        self.providers = providers
    }
}
