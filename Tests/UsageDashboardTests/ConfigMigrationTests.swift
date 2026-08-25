import Foundation
import Testing
@testable import UsageDashCore

private func tempConfigURL(name: String = "config") -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("migration-test-\(UUID().uuidString)")
        .appendingPathComponent("\(name).yaml")
}

private let legacyJSON = """
{
  "defaultIntervalSec": 300,
  "providers": [
    { "id": "kimi", "type": "kimi", "apiKeyEnv": "KIMI_API_KEY" },
    { "id": "cc", "type": "custom", "apiKey": "sk-cc",
      "request": { "url": "https://example.com/api", "method": "GET",
                   "headers": { "Authorization": "Bearer {{apiKey}}" } },
      "extractor": "function(r){ return r; }" }
  ]
}
"""

@Test func migratesLegacyJSONWhenYAMLMissing() throws {
    let yamlURL = tempConfigURL()
    let jsonURL = yamlURL.deletingPathExtension().appendingPathExtension("json")
    try FileManager.default.createDirectory(at: yamlURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data(legacyJSON.utf8).write(to: jsonURL)
    defer { try? FileManager.default.removeItem(at: yamlURL.deletingLastPathComponent()) }

    let result = try ConfigMigration.migrateIfNeeded(
        configURL: yamlURL,
        environment: ["KIMI_API_KEY": "sk-kimi"]
    )

    #expect(result == yamlURL)
    #expect(FileManager.default.fileExists(atPath: yamlURL.path))
    #expect(FileManager.default.fileExists(atPath: jsonURL.path))
}

@Test func migratedConfigPreservesSemantics() throws {
    let yamlURL = tempConfigURL()
    let jsonURL = yamlURL.deletingPathExtension().appendingPathExtension("json")
    try FileManager.default.createDirectory(at: yamlURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data(legacyJSON.utf8).write(to: jsonURL)
    defer { try? FileManager.default.removeItem(at: yamlURL.deletingLastPathComponent()) }

    _ = try ConfigMigration.migrateIfNeeded(
        configURL: yamlURL,
        environment: ["KIMI_API_KEY": "sk-kimi"]
    )

    let loaded = try ConfigLoader(environment: ["KIMI_API_KEY": "sk-kimi"]).load(url: yamlURL)
    #expect(loaded.defaultIntervalSec == 300)
    #expect(loaded.providers.map(\.id) == ["kimi", "cc"])
    #expect(loaded.providers.first?.apiKey == "sk-kimi")
    #expect(loaded.providers.first?.apiKeyEnv == "KIMI_API_KEY")
    #expect(loaded.providers.last?.custom?.url == "https://example.com/api")
}

@Test func usesExistingYAMLWithoutOverwriting() throws {
    let yamlURL = tempConfigURL()
    let jsonURL = yamlURL.deletingPathExtension().appendingPathExtension("json")
    try FileManager.default.createDirectory(at: yamlURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    let existingYAML = "defaultIntervalSec: 999\nproviders: []\n"
    try Data(existingYAML.utf8).write(to: yamlURL)
    try Data(legacyJSON.utf8).write(to: jsonURL)
    defer { try? FileManager.default.removeItem(at: yamlURL.deletingLastPathComponent()) }

    let result = try ConfigMigration.migrateIfNeeded(
        configURL: yamlURL,
        environment: ["KIMI_API_KEY": "sk-kimi"]
    )

    #expect(result == yamlURL)
    let content = try String(contentsOf: yamlURL, encoding: .utf8)
    #expect(content == existingYAML)
}

@Test func returnsURLWhenNeitherExists() throws {
    let yamlURL = tempConfigURL()
    try FileManager.default.createDirectory(at: yamlURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: yamlURL.deletingLastPathComponent()) }

    let result = try ConfigMigration.migrateIfNeeded(configURL: yamlURL, environment: [:])

    #expect(result == yamlURL)
    #expect(!FileManager.default.fileExists(atPath: yamlURL.path))
}
