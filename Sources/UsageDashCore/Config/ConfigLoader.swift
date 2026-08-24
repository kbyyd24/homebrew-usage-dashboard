import Foundation

public enum ConfigError: Error, Equatable, Sendable {
    case fileNotFound(String)
    case invalidJSON(String)
    case missingField(String)
    case missingEnvironment(String)
    case invalidType(String)
    case customRequiresRequest
    case customRequiresExtractor
}

public enum ConfigPath {
    public static var defaultURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/usage-dash/config.json")
    }

    public static func resolve(environment: [String: String]) -> URL {
        if let override = environment["USAGE_DASH_CONFIG"], !override.isEmpty {
            return URL(fileURLWithPath: override)
        }
        return defaultURL
    }
}

public struct ConfigLoader: Sendable {
    private let environment: [String: String]

    public init(environment: [String: String] = ProcessInfo.processInfo.environment) {
        self.environment = environment
    }

    public func load(url: URL) throws -> AppConfig {
        guard let data = try? Data(contentsOf: url) else {
            throw ConfigError.fileNotFound(url.path)
        }
        return try load(data: data)
    }

    public func load(data: Data) throws -> AppConfig {
        let raw: AppConfigJSON
        do {
            raw = try JSONDecoder().decode(AppConfigJSON.self, from: data)
        } catch {
            throw ConfigError.invalidJSON(error.localizedDescription)
        }

        let providers = try (raw.providers ?? []).enumerated().map { index, item in
            try Self.buildProvider(item, index: index, environment: environment)
        }
        return AppConfig(defaultIntervalSec: raw.defaultIntervalSec ?? 600, providers: providers)
    }

    private static func buildProvider(
        _ raw: ProviderConfigJSON,
        index: Int,
        environment: [String: String]
    ) throws -> ProviderConfig {
        let path = "providers[\(index)]"

        guard let id = raw.id?.trimmedNonEmpty else {
            throw ConfigError.missingField("\(path).id")
        }
        guard let typeRaw = raw.type?.trimmedNonEmpty else {
            throw ConfigError.missingField("\(path).type")
        }
        guard let type = ProviderType(rawValue: typeRaw) else {
            throw ConfigError.invalidType("\(path).type")
        }
        let name = raw.name?.trimmedNonEmpty ?? id

        let resolvedKey: String
        if let literal = raw.apiKey?.trimmedNonEmpty {
            resolvedKey = literal
        } else if let envName = raw.apiKeyEnv?.trimmedNonEmpty {
            guard let value = environment[envName], !value.isEmpty else {
                throw ConfigError.missingEnvironment(envName)
            }
            resolvedKey = value
        } else {
            throw ConfigError.missingField("\(path).apiKey or \(path).apiKeyEnv")
        }

        var custom: CustomQueryConfig?
        if type == .custom {
            guard let request = raw.request else {
                throw ConfigError.customRequiresRequest
            }
            guard let extractor = raw.extractor?.trimmedNonEmpty else {
                throw ConfigError.customRequiresExtractor
            }
            guard let url = request.url?.trimmedNonEmpty else {
                throw ConfigError.missingField("\(path).request.url")
            }
            let method = request.method?.trimmedNonEmpty ?? "GET"
            custom = CustomQueryConfig(
                url: url,
                method: method,
                headers: request.headers ?? [:],
                body: request.body,
                extractor: extractor
            )
        }

        return ProviderConfig(
            id: id,
            type: type,
            name: name,
            apiKeyEnv: raw.apiKeyEnv,
            apiKey: resolvedKey,
            refreshIntervalSec: raw.refreshIntervalSec,
            custom: custom
        )
    }
}

private struct AppConfigJSON: Decodable {
    let defaultIntervalSec: Int?
    let providers: [ProviderConfigJSON]?
}

private struct ProviderConfigJSON: Decodable {
    let id: String?
    let type: String?
    let name: String?
    let apiKeyEnv: String?
    let apiKey: String?
    let refreshIntervalSec: Int?
    let request: RequestJSON?
    let extractor: String?
}

private struct RequestJSON: Decodable {
    let url: String?
    let method: String?
    let headers: [String: String]?
    let body: String?
}

private extension String {
    var trimmedNonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
