import Foundation

public enum ProviderError: Error, Equatable, Sendable {
    case missingAPIKey(String)
    case invalidURL(String)
    case badResponse(String)
    case http(status: Int, body: String)
    case parse(String)
    case extractor(String)
}
