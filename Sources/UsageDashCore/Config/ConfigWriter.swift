import Foundation
import Yams

public enum ConfigWriter {
    public static func encode(_ config: AppConfig) throws -> String {
        let encoder = YAMLEncoder()
        encoder.options.newLineScalarStyle = .literal
        return try encoder.encode(AppConfigDTO(config))
    }

    public static func save(_ config: AppConfig, to url: URL) throws {
        let yaml = try encode(config)
        try yaml.write(to: url, atomically: true, encoding: .utf8)
    }
}

// Disk-shaped DTOs. The in-memory `AppConfig`/`ProviderConfig` bundle the
// custom query into `custom`, while the on-disk schema splits it into
// `request` (url/method/headers/body) + a top-level `extractor`. These DTOs
// bridge the two, and also keep env-referenced keys as `apiKeyEnv` so a
// resolved secret is never written back to the file as a literal.
private struct AppConfigDTO: Encodable {
    let defaultIntervalSec: Int
    let providers: [ProviderDTO]

    init(_ config: AppConfig) {
        self.defaultIntervalSec = config.defaultIntervalSec
        self.providers = config.providers.map(ProviderDTO.init)
    }
}

private struct ProviderDTO: Encodable {
    let id: String
    let type: String
    let name: String
    let apiKeyEnv: String?
    let apiKey: String?
    let refreshIntervalSec: Int?
    let request: RequestDTO?
    let extractor: String?

    init(_ provider: ProviderConfig) {
        self.id = provider.id
        self.type = provider.type.rawValue
        self.name = provider.name
        if let env = provider.apiKeyEnv {
            self.apiKeyEnv = env
            self.apiKey = nil
        } else {
            self.apiKeyEnv = nil
            self.apiKey = provider.apiKey
        }
        self.refreshIntervalSec = provider.refreshIntervalSec
        if let custom = provider.custom {
            self.request = RequestDTO(
                url: custom.url,
                method: custom.method,
                headers: custom.headers,
                body: custom.body
            )
            self.extractor = custom.extractor
        } else {
            self.request = nil
            self.extractor = nil
        }
    }
}

private struct RequestDTO: Encodable {
    let url: String
    let method: String
    let headers: [String: String]
    let body: String?
}
