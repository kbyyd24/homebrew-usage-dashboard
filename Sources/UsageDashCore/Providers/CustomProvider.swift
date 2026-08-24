import Foundation

public struct CustomProvider: UsageProvider {
    public let config: ProviderConfig
    private let httpClient: HTTPClient
    private let extractorRunner: ExtractorRunner

    public init(config: ProviderConfig, httpClient: HTTPClient, extractorRunner: ExtractorRunner) {
        self.config = config
        self.httpClient = httpClient
        self.extractorRunner = extractorRunner
    }

    public func fetch() async throws -> UsageSnapshot {
        guard let custom = config.custom else {
            throw ProviderError.parse("custom provider \(config.id) missing query config")
        }

        let request = try buildRequest()
        let (data, response) = try await httpClient.data(for: request)
        guard (200..<300).contains(response.statusCode) else {
            throw ProviderError.http(status: response.statusCode, body: String(data: data, encoding: .utf8) ?? "")
        }

        let body = String(data: data, encoding: .utf8) ?? ""
        let output: ExtractorOutput
        do {
            output = try extractorRunner.run(source: custom.extractor, responseJSON: body)
        } catch {
            return .error(providerId: config.id, message: ProviderError.describe(error))
        }

        if output.status == "error" {
            return .error(providerId: config.id, message: output.message)
        }

        return .ok(providerId: config.id, rows: output.rows.filter(\.isValid))
    }

    func buildRequest() throws -> URLRequest {
        guard let custom = config.custom else {
            throw ProviderError.parse("custom provider \(config.id) missing query config")
        }
        guard let apiKey = config.apiKey, !apiKey.isEmpty else {
            throw ProviderError.missingAPIKey(config.id)
        }

        let urlString = try AuthInjector.substitute(custom.url, apiKey: apiKey)
        guard let url = URL(string: urlString), url.scheme != nil else {
            throw ProviderError.invalidURL(custom.url)
        }

        var request = URLRequest(url: url)
        request.httpMethod = custom.method
        for (key, value) in custom.headers {
            request.setValue(try AuthInjector.substitute(value, apiKey: apiKey), forHTTPHeaderField: key)
        }
        if let body = custom.body {
            request.httpBody = try AuthInjector.substitute(body, apiKey: apiKey).data(using: .utf8)
        }
        return request
    }
}
