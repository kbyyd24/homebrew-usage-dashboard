import Foundation
import Testing
@testable import UsageDashCore

private let miniMaxFixture = """
{
  "model_remains": [
    { "model_name": "general",
      "current_interval_remaining_percent": 80.5,
      "current_weekly_remaining_percent": 70.0,
      "end_time": 1787554846343,
      "weekly_end_time": 1787843213320 },
    { "model_name": "video",
      "current_interval_remaining_percent": 99.0,
      "current_weekly_remaining_percent": 98.0,
      "end_time": 1787554846343,
      "weekly_end_time": 1787843213320 }
  ]
}
"""

@Test func miniMaxParserProducesTwoWindowRowsFromGeneral() throws {
    // Given a real-shaped MiniMax remains response with a "general" entry
    // When parsing
    let rows = try MiniMaxResponseParser.parse(data: Data(miniMaxFixture.utf8))

    // Then remaining percentages are converted into used/cap with millisecond reset times
    #expect(rows.count == 2)

    let fiveHour = rows[0]
    #expect(fiveHour.kind == .window)
    #expect(fiveHour.label == "5 小时")
    #expect(fiveHour.used == 19.5)
    #expect(fiveHour.cap == 100.0)
    #expect(fiveHour.resetAt?.timeIntervalSince1970 == 1_787_554_846.343)

    let weekly = rows[1]
    #expect(weekly.kind == .window)
    #expect(weekly.label == "本周")
    #expect(weekly.used == 30.0)
    #expect(weekly.cap == 100.0)
    #expect(weekly.resetAt?.timeIntervalSince1970 == 1_787_843_213.320)
}

@Test func miniMaxParserThrowsWhenGeneralMissing() {
    // Given a response that only contains a non-general model
    let fixture = """
    { "model_remains": [
        { "model_name": "video", "current_interval_remaining_percent": 99.0,
          "current_weekly_remaining_percent": 98.0,
          "end_time": 1787554846343, "weekly_end_time": 1787843213320 } ] }
    """

    // When parsing
    // Then a parse error is thrown
    #expect(throws: ProviderError.self) {
        try MiniMaxResponseParser.parse(data: Data(fixture.utf8))
    }
}

@Test func miniMaxFetchReturnsSnapshot() async throws {
    // Given a MiniMax provider backed by a stub returning the fixture
    let config = ProviderConfig(id: "minimax", type: .minimax, name: "MiniMax M3", apiKey: "sk-mm")
    let client = StubHTTPClient { request in
        #expect(request.url?.absoluteString == "https://api.minimaxi.com/v1/api/openplatform/coding_plan/remains")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer sk-mm")
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (Data(miniMaxFixture.utf8), response)
    }
    let provider = MiniMaxProvider(config: config, httpClient: client)

    // When fetching
    let snapshot = try await provider.fetch()

    // Then a successful snapshot with two rows is returned
    #expect(snapshot.providerId == "minimax")
    #expect(snapshot.status == .ok)
    #expect(snapshot.rows.count == 2)
    #expect(snapshot.rows[1].label == "本周")
}
