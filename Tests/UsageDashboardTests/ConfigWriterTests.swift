import Foundation
import Testing
@testable import UsageDashCore

private func customConfig() -> AppConfig {
    let custom = CustomQueryConfig(
        url: "https://example.com/api",
        method: "GET",
        headers: ["Authorization": "Bearer {{apiKey}}"],
        body: nil,
        extractor: "function(r){\n  return { status: 'ok', message: '', rows: r.rows };\n}"
    )
    let provider = ProviderConfig(
        id: "cc",
        type: .custom,
        name: "CommandCode",
        apiKey: "sk-cc",
        refreshIntervalSec: 120,
        custom: custom
    )
    return AppConfig(defaultIntervalSec: 600, providers: [provider])
}

@Test func encodeProducesExpectedYAML() throws {
    let yaml = try ConfigWriter.encode(customConfig())

    #expect(yaml.contains("defaultIntervalSec: 600"))
    #expect(yaml.contains("providers:"))
    #expect(yaml.contains("id: cc"))
    #expect(yaml.contains("type: custom"))
}

@Test func encodeUsesLiteralBlockScalarForMultilineExtractor() throws {
    let yaml = try ConfigWriter.encode(customConfig())

    #expect(yaml.contains("|"))
    #expect(yaml.contains("function(r){"))
}

@Test func encodeThenLoadRoundTrips() throws {
    let original = customConfig()
    let yaml = try ConfigWriter.encode(original)
    let decoded = try ConfigLoader(environment: [:]).load(data: Data(yaml.utf8))

    #expect(decoded == original)
}

@Test func encodeDoesNotLeakResolvedEnvSecret() throws {
    // Given a config whose key is env-referenced
    let source = """
    providers:
      - id: kimi
        type: kimi
        apiKeyEnv: KIMI_API_KEY
    """
    let loaded = try ConfigLoader(environment: ["KIMI_API_KEY": "sk-secret"]).load(data: Data(source.utf8))
    #expect(loaded.providers.first?.apiKey == "sk-secret")

    // When re-encoding
    let yaml = try ConfigWriter.encode(loaded)

    // Then the resolved secret is not written back as a literal
    #expect(!yaml.contains("sk-secret"))
    #expect(yaml.contains("apiKeyEnv: KIMI_API_KEY"))
}

@Test func saveWritesFileReadableByLoader() throws {
    let config = customConfig()
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("config-writer-test-\(UUID().uuidString).yaml")
    defer { try? FileManager.default.removeItem(at: url) }

    try ConfigWriter.save(config, to: url)

    let readBack = try ConfigLoader(environment: [:]).load(url: url)
    #expect(readBack == config)
}
