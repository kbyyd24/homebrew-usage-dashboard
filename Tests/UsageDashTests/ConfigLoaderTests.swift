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

@Test func configLoaderReportsMissingId() throws {
    // Given a provider without an id
    let data = try jsonData(["providers": [provider(["type": "kimi", "apiKey": "x"])]])

    // When & Then loading reports the missing field
    let error = #expect(throws: ConfigError.self) {
        try ConfigLoader(environment: [:]).load(data: data)
    }
    #expect(error == .missingField("providers[0].id"))
}

@Test func configLoaderReportsMissingType() throws {
    // Given a provider without a type
    let data = try jsonData(["providers": [provider(["id": "kimi", "apiKey": "x"])]])

    // When & Then loading reports the missing field
    let error = #expect(throws: ConfigError.self) {
        try ConfigLoader(environment: [:]).load(data: data)
    }
    #expect(error == .missingField("providers[0].type"))
}

@Test func configLoaderReportsMissingKey() throws {
    // Given a provider with neither apiKey nor apiKeyEnv
    let data = try jsonData(["providers": [provider(["id": "kimi", "type": "kimi"])]])

    // When & Then loading reports the missing key
    let error = #expect(throws: ConfigError.self) {
        try ConfigLoader(environment: [:]).load(data: data)
    }
    #expect(error == .missingField("providers[0].apiKey or providers[0].apiKeyEnv"))
}

@Test func configLoaderReportsBadJSON() {
    // Given malformed JSON
    let data = Data("{ not json".utf8)

    // When & Then loading reports invalid JSON
    let error = #expect(throws: ConfigError.self) {
        try ConfigLoader(environment: [:]).load(data: data)
    }
    guard case .invalidJSON = error else {
        Issue.record("expected invalidJSON, got \(String(describing: error))")
        return
    }
}

@Test func configLoaderReportsMissingEnvironment() throws {
    // Given a config referencing an environment variable that is absent
    let data = try jsonData([
        "providers": [provider(["id": "kimi", "type": "kimi", "apiKeyEnv": "KIMI_API_KEY"])],
    ])

    // When & Then loading reports the missing environment variable
    let error = #expect(throws: ConfigError.self) {
        try ConfigLoader(environment: [:]).load(data: data)
    }
    #expect(error == .missingEnvironment("KIMI_API_KEY"))
}

@Test func configLoaderReportsCustomMissingRequest() throws {
    // Given a custom provider without a request block
    let data = try jsonData([
        "providers": [provider(["id": "cc", "type": "custom", "apiKey": "x", "extractor": "f"])],
    ])

    // When & Then loading reports the missing request
    let error = #expect(throws: ConfigError.self) {
        try ConfigLoader(environment: [:]).load(data: data)
    }
    #expect(error == .customRequiresRequest)
}

@Test func configLoaderReportsCustomMissingExtractor() throws {
    // Given a custom provider without an extractor
    let data = try jsonData([
        "providers": [provider([
            "id": "cc", "type": "custom", "apiKey": "x",
            "request": ["url": "https://example.com/api"],
        ])],
    ])

    // When & Then loading reports the missing extractor
    let error = #expect(throws: ConfigError.self) {
        try ConfigLoader(environment: [:]).load(data: data)
    }
    #expect(error == .customRequiresExtractor)
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
