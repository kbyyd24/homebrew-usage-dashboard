import Foundation

public enum AuthInjector {
    public static func substitute(_ template: String, apiKey: String) throws -> String {
        guard template.contains("{{apiKey}}") else { return template }
        guard !apiKey.isEmpty else { throw ProviderError.missingAPIKey("apiKey is empty") }
        return template.replacingOccurrences(of: "{{apiKey}}", with: apiKey)
    }
}
