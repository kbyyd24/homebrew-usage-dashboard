import Foundation
import Testing
import UsageDashCore
@testable import UsageDashboard

private struct FakeExtractor: ExtractorRunner {
    func run(source: String, responseJSON: String) throws -> ExtractorOutput {
        ExtractorOutput(
            status: "ok",
            rows: [UsageRow(kind: .balance, label: "月度余额", balance: 42, unit: "credits")]
        )
    }
}

private let kimiBody = """
{"usage":{"limit":"100.0","remaining":"60.0","resetTime":"2026-08-30T00:00:00Z"},
 "limits":[{"window":{"duration":300,"timeUnit":"TIME_UNIT_MINUTE"},
            "detail":{"limit":"14.0","remaining":"13.0","resetTime":"2026-08-24T12:00:00Z"}}]}
"""

@MainActor
private func makeCoordinator() -> UsageCoordinator {
    let client = StubHTTPClient { request in
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (Data("{}".utf8), response)
    }
    return UsageCoordinator(httpClient: client, extractorRunner: FakeExtractor())
}

@MainActor
@Test func loadPopulatesProvidersFromConfig() {
    let config = AppConfig(
        defaultIntervalSec: 600,
        providers: [
            ProviderConfig(id: "kimi", type: .kimi, name: "Kimi", apiKeyEnv: "KIMI_API_KEY", apiKey: "sk-resolved"),
            ProviderConfig(
                id: "cc", type: .custom, name: "CC", apiKey: "sk-cc",
                custom: CustomQueryConfig(
                    url: "https://example.com", method: "POST",
                    headers: ["A": "b"], body: "{}", extractor: "f"
                )
            ),
        ]
    )
    let model = ConfigEditorModel(coordinator: makeCoordinator())

    model.load(config: config)

    #expect(model.providers.count == 2)
    #expect(model.providers[0].apiKeyEnvName == "KIMI_API_KEY")
    #expect(model.providers[0].apiKeyLiteral == "")
    #expect(model.providers[1].apiKeyLiteral == "sk-cc")
    #expect(model.providers[1].url == "https://example.com")
    #expect(model.providers[1].method == "POST")
    #expect(model.providers[1].headersText == "A: b")
    #expect(model.providers[1].body == "{}")
    #expect(model.providers[1].extractor == "f")
}

@MainActor
@Test func parseHeadersSplitsOnFirstColonAndIgnoresInvalidLines() {
    let headers = ConfigEditorModel.parseHeaders("Authorization: Bearer {{apiKey}}\nX-Token: abc:def\nno-colon-line\n")

    #expect(headers == ["Authorization": "Bearer {{apiKey}}", "X-Token": "abc:def"])
}

@MainActor
@Test func formatHeadersRoundTrips() {
    let formatted = ConfigEditorModel.formatHeaders(["Authorization": "Bearer x", "X-Token": "y"])
    #expect(ConfigEditorModel.parseHeaders(formatted) == ["Authorization": "Bearer x", "X-Token": "y"])
}

@MainActor
@Test func buildConfigMapsProviders() {
    let model = ConfigEditorModel(coordinator: makeCoordinator())
    model.defaultIntervalSec = 300
    model.providers = [
        .init(id: "kimi", type: .kimi, name: "Kimi", apiKeyLiteral: "sk-kimi", refreshIntervalSec: 120),
        .init(
            id: "cc", type: .custom, name: "CC", apiKeyEnvName: "CC_KEY",
            url: "https://example.com", method: "POST", headersText: "A: b\nC: d",
            body: "{}", extractor: "f"
        ),
    ]

    let config = model.buildConfig()

    #expect(config.defaultIntervalSec == 300)
    #expect(config.providers[0].apiKey == "sk-kimi")
    #expect(config.providers[0].apiKeyEnv == nil)
    #expect(config.providers[0].refreshIntervalSec == 120)
    #expect(config.providers[1].apiKeyEnv == "CC_KEY")
    #expect(config.providers[1].apiKey == nil)
    #expect(config.providers[1].custom?.method == "POST")
    #expect(config.providers[1].custom?.headers == ["A": "b", "C": "d"])
    #expect(config.providers[1].custom?.body == "{}")
}

@MainActor
@Test func validateCatchesMissingAndDuplicateFields() {
    let model = ConfigEditorModel(coordinator: makeCoordinator())

    #expect(model.validate() != nil) // empty provider list

    model.providers = [.init(type: .kimi, name: "K", apiKeyLiteral: "k")]
    #expect(model.validate() != nil) // empty id

    model.providers = [.init(id: "kimi", type: .kimi, name: "K")]
    #expect(model.validate() != nil) // missing key

    model.providers = [.init(id: "cc", type: .custom, name: "CC", apiKeyLiteral: "k")]
    #expect(model.validate() != nil) // custom missing url/extractor

    model.providers = [
        .init(id: "a", type: .kimi, name: "A", apiKeyLiteral: "k"),
        .init(id: "a", type: .kimi, name: "A2", apiKeyLiteral: "k2"),
    ]
    #expect(model.validate() != nil) // duplicate id

    model.providers = [.init(id: "a", type: .kimi, name: "A", apiKeyLiteral: "k")]
    #expect(model.validate() == nil) // valid
}

@MainActor
@Test func saveWritesYAMLAndReloads() async throws {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("editor-\(UUID().uuidString).yaml")
    defer { try? FileManager.default.removeItem(at: url) }
    let coordinator = makeCoordinator()
    let model = ConfigEditorModel(coordinator: coordinator)
    model.providers = [.init(id: "kimi", type: .kimi, name: "Kimi", apiKeyLiteral: "sk-kimi")]

    await model.save(to: url)

    #expect(model.errorMessage == nil)
    #expect(FileManager.default.fileExists(atPath: url.path))
    #expect(coordinator.config?.providers.map(\.id) == ["kimi"])
}

@MainActor
@Test func testConnectionSuccess() async throws {
    let client = StubHTTPClient { request in
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (Data(kimiBody.utf8), response)
    }
    let coordinator = UsageCoordinator(httpClient: client, extractorRunner: FakeExtractor())
    let model = ConfigEditorModel(coordinator: coordinator)
    model.providers = [.init(id: "kimi", type: .kimi, name: "Kimi", apiKeyLiteral: "sk-kimi")]

    await model.testConnection(for: "kimi")

    let snapshot = model.testSnapshots["kimi"]
    #expect(snapshot?.status == .ok)
    #expect(snapshot?.rows.count == 2)
}

@MainActor
@Test func testConnectionReportsMissingEnv() async {
    let model = ConfigEditorModel(coordinator: makeCoordinator(), environment: [:])
    model.providers = [.init(id: "kimi", type: .kimi, name: "Kimi", apiKeyEnvName: "KIMI_API_KEY")]

    await model.testConnection(for: "kimi")

    let snapshot = model.testSnapshots["kimi"]
    #expect(snapshot?.status == .error)
    #expect(snapshot?.message?.contains("KIMI_API_KEY") == true)
}
