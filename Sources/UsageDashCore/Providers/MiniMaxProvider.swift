import Foundation

public enum MiniMaxResponseParser {
    public static func parse(data: Data) throws -> [UsageRow] {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let remains = root["model_remains"] as? [[String: Any]] else {
            throw ProviderError.parse("MiniMax response missing model_remains")
        }

        guard let general = remains.first(where: { ($0["model_name"] as? String) == "general" }) else {
            throw ProviderError.parse("MiniMax response has no 'general' model entry")
        }

        guard let intervalPercent = JSONNumber.double(general["current_interval_remaining_percent"]),
              let weeklyPercent = JSONNumber.double(general["current_weekly_remaining_percent"]) else {
            throw ProviderError.parse("MiniMax general entry missing remaining percent")
        }

        let intervalEnd = JSONNumber.double(general["end_time"]).map(DateParsing.parseMilliseconds)
        let weeklyEnd = JSONNumber.double(general["weekly_end_time"]).map(DateParsing.parseMilliseconds)

        return [
            UsageRow(kind: .window, label: "5 小时", used: 100 - intervalPercent, cap: 100, resetAt: intervalEnd),
            UsageRow(kind: .window, label: "本周", used: 100 - weeklyPercent, cap: 100, resetAt: weeklyEnd),
        ]
    }
}

public struct MiniMaxProvider: UsageProvider {
    public let config: ProviderConfig
    private let httpClient: HTTPClient

    public init(config: ProviderConfig, httpClient: HTTPClient) {
        self.config = config
        self.httpClient = httpClient
    }

    public func fetch() async throws -> UsageSnapshot {
        guard let apiKey = config.apiKey, !apiKey.isEmpty else {
            throw ProviderError.missingAPIKey(config.id)
        }
        guard let url = URL(string: "https://api.minimaxi.com/v1/api/openplatform/coding_plan/remains") else {
            throw ProviderError.invalidURL("minimax remains")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await httpClient.data(for: request)
        guard (200..<300).contains(response.statusCode) else {
            throw ProviderError.http(status: response.statusCode, body: String(data: data, encoding: .utf8) ?? "")
        }

        let rows = try MiniMaxResponseParser.parse(data: data)
        return .ok(providerId: config.id, rows: rows)
    }
}
