import Foundation
import Testing
@testable import UsageDashCore

private struct FakeExtractorRunner: ExtractorRunner {
    let output: ExtractorOutput
    func run(source: String, responseJSON: String) throws -> ExtractorOutput { output }
}

private struct ThrowingExtractorRunner: ExtractorRunner {
    func run(source: String, responseJSON: String) throws -> ExtractorOutput {
        throw ProviderError.extractor("boom")
    }
}

private func customConfig(
    url: String = "https://example.com/api",
    method: String = "GET",
    headers: [String: String] = [:],
    body: String? = nil,
    apiKey: String = "sk-abc",
    extractor: String = "function(r){ return r; }"
) -> ProviderConfig {
    ProviderConfig(
        id: "cc",
        type: .custom,
        name: "CommandCode",
        apiKey: apiKey,
        custom: CustomQueryConfig(url: url, method: method, headers: headers, body: body, extractor: extractor)
    )
}

@Test func customProviderBuildRequestSubstitutesPlaceholders() throws {
    // Given a custom query with placeholders in url, headers, and body
    let config = customConfig(
        url: "https://example.com/usage/{{apiKey}}",
        method: "POST",
        headers: ["Authorization": "Bearer {{apiKey}}"],
        body: "{\"key\":\"{{apiKey}}\"}",
        apiKey: "sk-abc"
    )
    let provider = CustomProvider(config: config, httpClient: StubHTTPClient { _ in
        throw ProviderError.badResponse("unused")
    }, extractorRunner: FakeExtractorRunner(output: ExtractorOutput()))

    // When building the request
    let request = try provider.buildRequest()

    // Then placeholders are replaced in url, headers, and body
    #expect(request.url?.absoluteString == "https://example.com/usage/sk-abc")
    #expect(request.httpMethod == "POST")
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer sk-abc")
    #expect(request.httpBody == Data("{\"key\":\"sk-abc\"}".utf8))
}

@Test func customProviderFetchBridgesExtractorOutput() async throws {
    // Given a stub response and a fake extractor returning valid and invalid rows
    let config = customConfig(extractor: "function(r){ return r; }")
    let reset = Date(timeIntervalSince1970: 1_787_554_846.343)
    let output = ExtractorOutput(
        status: "ok",
        rows: [
            UsageRow(kind: .window, label: "5 小时", used: 1, cap: 14, resetAt: reset),
            UsageRow(kind: .window, label: "broken", used: 1, cap: nil),
            UsageRow(kind: .balance, label: "月度余额", balance: 69.5, unit: "credits"),
            UsageRow(kind: .balance, label: "empty", balance: nil, unit: "credits"),
        ]
    )
    let client = StubHTTPClient { request in
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (Data("{\"credits\":{}}".utf8), response)
    }
    let provider = CustomProvider(config: config, httpClient: client, extractorRunner: FakeExtractorRunner(output: output))

    // When fetching
    let snapshot = try await provider.fetch()

    // Then invalid rows are skipped and valid rows are preserved in order
    #expect(snapshot.providerId == "cc")
    #expect(snapshot.status == .ok)
    #expect(snapshot.rows.count == 2)
    #expect(snapshot.rows[0].label == "5 小时")
    #expect(snapshot.rows[0].resetAt == reset)
    #expect(snapshot.rows[1].label == "月度余额")
    #expect(snapshot.rows[1].balance == 69.5)
}

@Test func customProviderFetchReturnsErrorSnapshotForErrorStatus() async throws {
    // Given a fake extractor that reports status "error"
    let output = ExtractorOutput(status: "error", message: "quota lookup failed", rows: [])
    let client = StubHTTPClient { request in
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (Data("{}".utf8), response)
    }
    let provider = CustomProvider(config: customConfig(), httpClient: client, extractorRunner: FakeExtractorRunner(output: output))

    // When fetching
    let snapshot = try await provider.fetch()

    // Then an error snapshot with the extractor message is returned
    #expect(snapshot.status == .error)
    #expect(snapshot.message == "quota lookup failed")
    #expect(snapshot.rows.isEmpty)
}

@Test func customProviderFetchReturnsErrorSnapshotWhenExtractorThrows() async throws {
    // Given an extractor runner that throws
    let client = StubHTTPClient { request in
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (Data("{}".utf8), response)
    }
    let provider = CustomProvider(config: customConfig(), httpClient: client, extractorRunner: ThrowingExtractorRunner())

    // When fetching
    let snapshot = try await provider.fetch()

    // Then a script error becomes an error snapshot rather than crashing
    #expect(snapshot.status == .error)
    #expect(snapshot.message == "extractor error: boom")
}

@Test func customProviderThrowsGivenInvalidURL() {
    // Given a custom query with a non-URL string
    let config = customConfig(url: "not a url")
    let provider = CustomProvider(config: config, httpClient: StubHTTPClient { _ in
        throw ProviderError.badResponse("unused")
    }, extractorRunner: FakeExtractorRunner(output: ExtractorOutput()))

    // When building the request
    // Then an invalid-url error is thrown
    let error = #expect(throws: ProviderError.self) {
        try provider.buildRequest()
    }
    guard case .invalidURL = error else {
        Issue.record("expected invalidURL, got \(String(describing: error))")
        return
    }
}
