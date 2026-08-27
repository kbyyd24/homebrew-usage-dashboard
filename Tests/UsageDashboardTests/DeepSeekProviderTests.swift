import Foundation
import Testing
@testable import UsageDashCore

private let deepSeekFixture = """
{
  "is_available": true,
  "balance_infos": [
    { "currency": "CNY",
      "total_balance": "110.00",
      "granted_balance": "10.00",
      "topped_up_balance": "100.00" },
    { "currency": "USD",
      "total_balance": "5.25",
      "granted_balance": "0.00",
      "topped_up_balance": "5.25" }
  ]
}
"""

@Test func deepSeekParserProducesBalanceRowPerCurrency() throws {
    // Given a real-shaped DeepSeek balance response with two currencies
    // When parsing
    let rows = try DeepSeekResponseParser.parse(data: Data(deepSeekFixture.utf8))

    // Then one balance row is produced per currency, with string values parsed to doubles
    #expect(rows.count == 2)

    let cny = rows[0]
    #expect(cny.kind == .balance)
    #expect(cny.label == "余额 (CNY)")
    #expect(cny.balance == 110.0)
    #expect(cny.unit == "CNY")

    let usd = rows[1]
    #expect(usd.kind == .balance)
    #expect(usd.label == "余额 (USD)")
    #expect(usd.balance == 5.25)
    #expect(usd.unit == "USD")
}

@Test func deepSeekParserThrowsWhenBalanceInfosMissing() {
    // Given a response with no balance_infos key
    let fixture = #"{ "is_available": true }"#

    // When parsing
    // Then a parse error is thrown
    #expect(throws: ProviderError.self) {
        try DeepSeekResponseParser.parse(data: Data(fixture.utf8))
    }
}

@Test func deepSeekParserThrowsWhenNoParseableEntries() {
    // Given a balance_infos entry missing its currency/total_balance
    let fixture = #"{ "balance_infos": [ { "currency": "CNY" } ] }"#

    // When parsing
    // Then a parse error is thrown
    #expect(throws: ProviderError.self) {
        try DeepSeekResponseParser.parse(data: Data(fixture.utf8))
    }
}

@Test func deepSeekFetchReturnsSnapshot() async throws {
    // Given a DeepSeek provider backed by a stub returning the fixture
    let config = ProviderConfig(id: "deepseek", type: .deepseek, name: "DeepSeek", apiKey: "sk-ds")
    let client = StubHTTPClient { request in
        #expect(request.url?.absoluteString == "https://api.deepseek.com/user/balance")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer sk-ds")
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (Data(deepSeekFixture.utf8), response)
    }
    let provider = DeepSeekProvider(config: config, httpClient: client)

    // When fetching
    let snapshot = try await provider.fetch()

    // Then a successful snapshot with a balance row is returned
    #expect(snapshot.providerId == "deepseek")
    #expect(snapshot.status == .ok)
    #expect(snapshot.rows.count == 2)
    #expect(snapshot.rows[0].unit == "CNY")
}
