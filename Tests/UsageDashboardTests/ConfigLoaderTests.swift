import Foundation
import Testing
@testable import UsageDashCore

private func jsonData(_ object: Any) throws -> Data {
    try JSONSerialization.data(withJSONObject: object)
}

private func provider(_ fields: [String: Any]) -> [String: Any] { fields }

@Test func configLoaderResolvesApiKeyEnvReference() throws {
    // Given a config referencing an environment variable that is present
    let data = try jsonData([
        "providers": [provider(["id": "kimi", "type": "kimi", "apiKeyEnv": "KIMI_API_KEY"])],
    ])
    let loader = ConfigLoader(environment: ["KIMI_API_KEY": "sk-kimi"])

    // When loading
    let config = try loader.load(data: data)

    // Then the key is resolved into the provider config
    #expect(config.providers.first?.apiKey == "sk-kimi")
    #expect(config.providers.first?.apiKeyEnv == "KIMI_API_KEY")
}

@Test func configLoaderKeepsLiteralApiKey() throws {
    // Given a config with a literal key
    let data = try jsonData([
        "providers": [provider(["id": "kimi", "type": "kimi", "apiKey": "sk-literal"])],
    ])

    // When loading
    let config = try ConfigLoader(environment: [:]).load(data: data)

    // Then the literal key is kept as-is
    #expect(config.providers.first?.apiKey == "sk-literal")
}

@Test func configLoaderAppliesDefaults() throws {
    // Given a minimal config omitting name, interval, and custom method
    let data = try jsonData([
        "providers": [
            provider(["id": "kimi", "type": "kimi", "apiKey": "x"]),
            provider([
                "id": "cc", "type": "custom", "apiKey": "y",
                "request": ["url": "https://example.com/api"],
                "extractor": "function(r){ return r; }",
            ]),
        ],
    ])

    // When loading
    let config = try ConfigLoader(environment: [:]).load(data: data)

    // Then defaults are applied
    #expect(config.defaultIntervalSec == 600)
    #expect(config.providers[0].name == "kimi")
    #expect(config.providers[1].custom?.method == "GET")
}

@Test func configLoaderSkipsProviderMissingIdAndWarns() throws {
    // Given a provider without an id alongside none other
    let data = try jsonData(["providers": [provider(["type": "kimi", "apiKey": "x"])]])

    // When loading (fail-soft)
    let config = try ConfigLoader(environment: [:]).load(data: data)

    // Then the provider is skipped with a warning, not a hard failure
    #expect(config.providers.isEmpty)
    #expect(config.warnings.count == 1)
    #expect(config.warnings[0].contains("providers[0]"))
    #expect(config.warnings[0].contains("missing config field"))
}

@Test func configLoaderSkipsProviderMissingTypeAndWarns() throws {
    // Given a provider without a type
    let data = try jsonData(["providers": [provider(["id": "kimi", "apiKey": "x"])]])

    // When loading (fail-soft)
    let config = try ConfigLoader(environment: [:]).load(data: data)

    // Then skip + warn
    #expect(config.providers.isEmpty)
    #expect(config.warnings[0].contains("missing config field"))
}

@Test func configLoaderSkipsProviderMissingKeyAndWarns() throws {
    // Given a provider with neither apiKey nor apiKeyEnv
    let data = try jsonData(["providers": [provider(["id": "kimi", "type": "kimi"])]])

    // When loading (fail-soft)
    let config = try ConfigLoader(environment: [:]).load(data: data)

    // Then skip + warn about the missing key
    #expect(config.providers.isEmpty)
    #expect(config.warnings[0].contains("apiKey or"))
}

@Test func configLoaderSkipsProviderMissingEnvironmentAndWarns() throws {
    // Given a config referencing an environment variable that is absent
    let data = try jsonData([
        "providers": [provider(["id": "kimi", "type": "kimi", "apiKeyEnv": "KIMI_API_KEY"])],
    ])

    // When loading with an empty environment (fail-soft)
    let config = try ConfigLoader(environment: [:]).load(data: data)

    // Then skip + warn about the missing environment variable
    #expect(config.providers.isEmpty)
    #expect(config.warnings[0].contains("missing environment variable"))
    #expect(config.warnings[0].contains("KIMI_API_KEY"))
}

@Test func configLoaderSkipsCustomMissingRequestAndWarns() throws {
    // Given a custom provider without a request block
    let data = try jsonData([
        "providers": [provider(["id": "cc", "type": "custom", "apiKey": "x", "extractor": "f"])],
    ])

    // When loading (fail-soft)
    let config = try ConfigLoader(environment: [:]).load(data: data)

    // Then skip + warn
    #expect(config.providers.isEmpty)
    #expect(config.warnings[0].contains("request"))
}

@Test func configLoaderSkipsCustomMissingExtractorAndWarns() throws {
    // Given a custom provider without an extractor
    let data = try jsonData([
        "providers": [provider([
            "id": "cc", "type": "custom", "apiKey": "x",
            "request": ["url": "https://example.com/api"],
        ])],
    ])

    // When loading (fail-soft)
    let config = try ConfigLoader(environment: [:]).load(data: data)

    // Then skip + warn
    #expect(config.providers.isEmpty)
    #expect(config.warnings[0].contains("extractor"))
}

@Test func configLoaderKeepsValidProvidersWhenOneIsBad() throws {
    // Given one valid provider and one bad provider (missing key)
    let data = try jsonData([
        "providers": [
            provider(["id": "kimi", "type": "kimi", "apiKey": "sk-kimi"]),
            provider(["id": "cc", "type": "custom", "apiKeyEnv": "CC_KEY"]),
        ],
    ])

    // When loading with CC_KEY absent (fail-soft)
    let config = try ConfigLoader(environment: [:]).load(data: data)

    // Then the valid provider loads, the bad one is skipped with a warning
    #expect(config.providers.map(\.id) == ["kimi"])
    #expect(config.warnings.count == 1)
    #expect(config.warnings[0].contains("cc"))
}

@Test func configLoaderReportsBadJSON() {
    // Given malformed JSON
    let data = Data("{ not json".utf8)

    // When & Then loading reports invalid JSON (config-level, still hard)
    let error = #expect(throws: ConfigError.self) {
        try ConfigLoader(environment: [:]).load(data: data)
    }
    guard case .invalidJSON = error else {
        Issue.record("expected invalidJSON, got \(String(describing: error))")
        return
    }
}

@Test func configLoaderHonorsPerProviderIntervalOverride() throws {
    // Given one provider with an explicit interval and one without
    let data = try jsonData([
        "defaultIntervalSec": 600,
        "providers": [
            provider(["id": "a", "type": "kimi", "apiKey": "x", "refreshIntervalSec": 120]),
            provider(["id": "b", "type": "kimi", "apiKey": "y"]),
        ],
    ])

    // When loading
    let config = try ConfigLoader(environment: [:]).load(data: data)

    // Then only the first provider overrides the interval
    #expect(config.providers[0].refreshIntervalSec == 120)
    #expect(config.providers[1].refreshIntervalSec == nil)
}
