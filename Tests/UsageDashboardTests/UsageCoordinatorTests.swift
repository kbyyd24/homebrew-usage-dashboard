import Foundation
import Testing
@testable import UsageDashCore

private struct FakeExtractor: ExtractorRunner {
    func run(source: String, responseJSON: String) throws -> ExtractorOutput {
        ExtractorOutput(
            status: "ok",
            rows: [UsageRow(kind: .balance, label: "月度余额", balance: 42, unit: "credits")]
        )
    }
}

private func writeTempConfig(_ object: [String: Any]) throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("usage-dash-\(UUID().uuidString).json")
    try JSONSerialization.data(withJSONObject: object).write(to: url)
    return url
}

private let kimiBody = """
{"usage":{"limit":"100.0","remaining":"60.0","resetTime":"2026-08-30T00:00:00Z"},
 "limits":[{"window":{"duration":300,"timeUnit":"TIME_UNIT_MINUTE"},
            "detail":{"limit":"14.0","remaining":"13.0","resetTime":"2026-08-24T12:00:00Z"}}]}
"""

@MainActor
@Test func coordinatorAssemblesProvidersAndPopulatesStore() async throws {
    // Given a valid config and fakes for HTTP and extraction
    let configURL = try writeTempConfig([
        "defaultIntervalSec": 600,
        "providers": [
            ["id": "kimi", "type": "kimi", "name": "Kimi Code", "apiKeyEnv": "KIMI_API_KEY"],
            [
                "id": "cc", "type": "custom", "name": "CommandCode", "apiKey": "sk-cc",
                "request": ["url": "https://example.com/cc", "method": "GET"],
                "extractor": "function(r){ return r; }",
            ],
        ],
    ])
    let client = StubHTTPClient { request in
        let url = request.url!.absoluteString
        let body: Data
        if url == "https://api.kimi.com/coding/v1/usages" {
            body = Data(kimiBody.utf8)
        } else if url == "https://example.com/cc" {
            body = Data("{}".utf8)
        } else {
            throw ProviderError.badResponse("unexpected url \(url)")
        }
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (body, response)
    }
    let coordinator = UsageCoordinator(httpClient: client, extractorRunner: FakeExtractor())

    // When starting with a fixed environment
    await coordinator.start(configURL: configURL, environment: ["KIMI_API_KEY": "sk-kimi"])

    // Then the store has snapshots and the view model has display data
    #expect(coordinator.configError == nil)
    #expect(coordinator.store.snapshot(forId: "kimi")?.status == .ok)
    #expect(coordinator.store.snapshot(forId: "kimi")?.rows.count == 2)
    #expect(coordinator.store.snapshot(forId: "cc")?.status == .ok)
    #expect(coordinator.store.snapshot(forId: "cc")?.rows.count == 1)

    let dashboard = try #require(coordinator.dashboard)
    let providers = dashboard.display()
    #expect(providers.count == 2)
    #expect(providers[0].name == "Kimi Code")
    #expect(providers[0].rows.count == 2)
    #expect(providers[1].name == "CommandCode")
    #expect(providers[1].rows.first?.label == "月度余额")
}

@MainActor
@Test func coordinatorSurfacesConfigErrorWithoutCrashing() async throws {
    // Given a config URL that does not exist (a file-level error)
    let configURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("does-not-exist-\(UUID().uuidString).json")
    let coordinator = UsageCoordinator(httpClient: StubHTTPClient { _ in
        throw ProviderError.badResponse("unused")
    }, extractorRunner: FakeExtractor())

    // When starting
    await coordinator.start(configURL: configURL, environment: [:])

    // Then a readable error is exposed and no dashboard is assembled
    #expect(coordinator.configError?.contains("config file not found") == true)
    #expect(coordinator.dashboard == nil)
}

@MainActor
@Test func coordinatorSkipsBadProviderAndLoadsValidOnes() async throws {
    // Given a config with one valid provider and one bad provider (missing env var)
    let configURL = try writeTempConfig([
        "providers": [
            ["id": "kimi", "type": "kimi", "name": "Kimi Code", "apiKeyEnv": "KIMI_API_KEY"],
            ["id": "cc", "type": "custom", "name": "CommandCode", "apiKeyEnv": "COMMANDCODE_API_KEY",
             "request": ["url": "https://example.com/cc", "method": "GET"],
             "extractor": "function(r){ return r; }"],
        ],
    ])
    let coordinator = UsageCoordinator(httpClient: StubHTTPClient { _ in
        throw ProviderError.badResponse("unused")
    }, extractorRunner: FakeExtractor())

    // When starting with only KIMI_API_KEY set (fail-soft)
    await coordinator.start(configURL: configURL, environment: ["KIMI_API_KEY": "sk-kimi"])

    // Then the bad provider is skipped with a warning, the valid one still loads
    #expect(coordinator.configError == nil)
    #expect(coordinator.configWarnings.count == 1)
    #expect(coordinator.configWarnings[0].contains("cc"))
    let dashboard = try #require(coordinator.dashboard)
    #expect(dashboard.display().map(\.id) == ["kimi"])
}
