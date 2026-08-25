import Foundation
import Testing
@testable import UsageDashCore

@Test func bundledExampleYAMLParses() throws {
    // Given the shipped example config (relative to the package root)
    let url = URL(fileURLWithPath: "docs/config.example.yaml")
    let loader = ConfigLoader(environment: [
        "KIMI_API_KEY": "x",
        "MINIMAX_API_KEY": "y",
        "COMMANDCODE_API_KEY": "z",
    ])

    // When loading it
    let config = try loader.load(url: url)

    // Then all three providers parse, including the multi-line extractor
    #expect(config.providers.count == 3)
    #expect(config.providers.map(\.id) == ["kimi", "minimax", "commandcode"])
    let custom = try #require(config.providers.last?.custom)
    #expect(custom.url == "https://api.commandcode.ai/alpha/billing/credits")
    #expect(custom.headers == ["Authorization": "Bearer {{apiKey}}"])
    #expect(custom.extractor.contains("windowLimits"))
    #expect(custom.extractor.contains("function(response)"))
}
