import Foundation

public enum DeepSeekResponseParser {
    public static func parse(data: Data) throws -> [UsageRow] {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let infos = root["balance_infos"] as? [[String: Any]] else {
            throw ProviderError.parse("DeepSeek response missing balance_infos")
        }

        let rows = infos.compactMap { info -> UsageRow? in
            guard let currency = info["currency"] as? String,
                  let balance = JSONNumber.double(info["total_balance"]) else {
                return nil
            }
            return UsageRow(kind: .balance, label: "余额 (\(currency))", balance: balance, unit: currency)
        }

        guard !rows.isEmpty else {
            throw ProviderError.parse("DeepSeek response has no parseable balance entry")
        }
        return rows
    }
}

public struct DeepSeekProvider: UsageProvider {
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
        guard let url = URL(string: "https://api.deepseek.com/user/balance") else {
            throw ProviderError.invalidURL("deepseek balance")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await httpClient.data(for: request)
        guard (200..<300).contains(response.statusCode) else {
            throw ProviderError.http(status: response.statusCode, body: String(data: data, encoding: .utf8) ?? "")
        }

        let rows = try DeepSeekResponseParser.parse(data: data)
        return .ok(providerId: config.id, rows: rows)
    }
}
