import Foundation
import Testing
@testable import UsageDashCore

private let kimiFixture = """
{
  "usage": { "limit": "100.0", "remaining": "60.0", "resetTime": "2026-08-30T00:00:00Z" },
  "limits": [
    { "window": { "duration": 300, "timeUnit": "TIME_UNIT_MINUTE" },
      "detail": { "limit": "14.0", "remaining": "13.0", "resetTime": "2026-08-24T12:00:00Z" } }
  ]
}
"""

@Test func kimiParserProducesTwoWindowRows() throws {
    // Given a real-shaped Kimi usage response (string numbers, ISO reset times)
    // When parsing
    let rows = try KimiResponseParser.parse(data: Data(kimiFixture.utf8))

    // Then it yields the 5-hour window then the weekly window
    #expect(rows.count == 2)

    let fiveHour = rows[0]
    #expect(fiveHour.kind == .window)
    #expect(fiveHour.label == "5 小时")
    #expect(fiveHour.used == 1.0)
    #expect(fiveHour.cap == 14.0)
    #expect(fiveHour.resetAt?.timeIntervalSince1970 == 1_787_572_800.0)

    let weekly = rows[1]
    #expect(weekly.kind == .window)
    #expect(weekly.label == "本周")
    #expect(weekly.used == 40.0)
    #expect(weekly.cap == 100.0)
    #expect(weekly.resetAt?.timeIntervalSince1970 == 1_788_048_000.0)
}

@Test func kimiFetchReturnsSnapshot() async throws {
    // Given a Kimi provider backed by a stub returning the fixture
    let config = ProviderConfig(id: "kimi", type: .kimi, name: "Kimi Code", apiKey: "sk-kimi")
    let client = StubHTTPClient { request in
        #expect(request.url?.absoluteString == "https://api.kimi.com/coding/v1/usages")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer sk-kimi")
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (Data(kimiFixture.utf8), response)
    }
    let provider = KimiProvider(config: config, httpClient: client)

    // When fetching
    let snapshot = try await provider.fetch()

    // Then a successful snapshot with two rows is returned
    #expect(snapshot.providerId == "kimi")
    #expect(snapshot.status == .ok)
    #expect(snapshot.rows.count == 2)
    #expect(snapshot.rows[0].label == "5 小时")
}

@Test func kimiFetchThrowsOnNon200() async {
    // Given a stub that returns a 401
    let config = ProviderConfig(id: "kimi", type: .kimi, name: "Kimi Code", apiKey: "bad")
    let client = StubHTTPClient { request in
        let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
        return (Data("unauthorized".utf8), response)
    }
    let provider = KimiProvider(config: config, httpClient: client)

    // When fetching
    // Then a non-200 status is surfaced as a provider error
    let error = await #expect(throws: ProviderError.self) {
        try await provider.fetch()
    }
    guard case .http(status: 401, _) = error else {
        Issue.record("expected http 401, got \(String(describing: error))")
        return
    }
}
