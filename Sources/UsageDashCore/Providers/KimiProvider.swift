import Foundation

public enum KimiResponseParser {
    public static func parse(data: Data) throws -> [UsageRow] {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ProviderError.parse("Kimi response is not a JSON object")
        }

        guard let usage = root["usage"] as? [String: Any],
              let weekly = parseWindow(usage) else {
            throw ProviderError.parse("Kimi response missing usage.limit/remaining")
        }

        guard let limits = root["limits"] as? [[String: Any]],
              let detail = limits.first?["detail"] as? [String: Any],
              let fiveHour = parseWindow(detail) else {
            throw ProviderError.parse("Kimi response missing limits[0].detail")
        }

        return [
            UsageRow(kind: .window, label: "5 小时", used: fiveHour.used, cap: fiveHour.cap, resetAt: fiveHour.resetAt),
            UsageRow(kind: .window, label: "本周", used: weekly.used, cap: weekly.cap, resetAt: weekly.resetAt),
        ]
    }

    private static func parseWindow(_ dict: [String: Any]) -> (used: Double, cap: Double, resetAt: Date?)? {
        guard let limit = JSONNumber.double(dict["limit"]),
              let remaining = JSONNumber.double(dict["remaining"]) else {
            return nil
        }
        let resetAt = (dict["resetTime"] as? String).flatMap(DateParsing.parseISO8601)
        return (max(limit - remaining, 0), limit, resetAt)
    }
}

public struct KimiProvider: UsageProvider {
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
        guard let url = URL(string: "https://api.kimi.com/coding/v1/usages") else {
            throw ProviderError.invalidURL("kimi usages")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await httpClient.data(for: request)
        guard (200..<300).contains(response.statusCode) else {
            throw ProviderError.http(status: response.statusCode, body: String(data: data, encoding: .utf8) ?? "")
        }

        let rows = try KimiResponseParser.parse(data: data)
        return .ok(providerId: config.id, rows: rows)
    }
}
