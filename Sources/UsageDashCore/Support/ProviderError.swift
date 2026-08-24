import Foundation

public enum ProviderError: Error, Equatable, Sendable {
    case missingAPIKey(String)
    case invalidURL(String)
    case badResponse(String)
    case http(status: Int, body: String)
    case parse(String)
    case extractor(String)

    public var message: String {
        switch self {
        case .missingAPIKey(let detail): return "missing api key: \(detail)"
        case .invalidURL(let detail): return "invalid url: \(detail)"
        case .badResponse(let detail): return detail
        case .http(let status, let body): return "http \(status): \(body)"
        case .parse(let detail): return "parse error: \(detail)"
        case .extractor(let detail): return "extractor error: \(detail)"
        }
    }

    public static func describe(_ error: Error) -> String {
        if let providerError = error as? ProviderError {
            return providerError.message
        }
        return error.localizedDescription
    }
}
