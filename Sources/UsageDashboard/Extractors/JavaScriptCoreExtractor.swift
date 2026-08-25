import Foundation
import JavaScriptCore
import UsageDashCore

public struct JavaScriptCoreExtractor: ExtractorRunner {
    public init() {}

    public func run(source: String, responseJSON: String) throws -> ExtractorOutput {
        guard let context = JSContext() else {
            throw ProviderError.extractor("unable to create JS context")
        }

        let safeResponse = responseJSON.isEmpty ? "null" : responseJSON
        context.evaluateScript("var __response = \(safeResponse)")
        if let exception = context.exception {
            throw ProviderError.extractor("response parse failed: \(exception.toString() ?? "unknown")")
        }

        let value = context.evaluateScript("JSON.stringify((\(source))(__response))")
        if let exception = context.exception {
            throw ProviderError.extractor(exception.toString() ?? "unknown JS error")
        }
        guard let value, !value.isUndefined, let json = value.toString() else {
            throw ProviderError.extractor("extractor did not return a value")
        }

        guard let data = json.data(using: .utf8),
              let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            throw ProviderError.extractor("extractor returned an invalid structure")
        }

        let status = object["status"] as? String ?? "ok"
        let message = object["message"] as? String ?? ""
        return ExtractorOutput(status: status, message: message, rows: Self.parseRows(object["rows"]))
    }

    private static func parseRows(_ value: Any?) -> [UsageRow] {
        guard let array = value as? [[String: Any]] else { return [] }
        return array.compactMap { dict -> UsageRow? in
            guard let kindRaw = dict["kind"] as? String,
                  let kind = RowKind(rawValue: kindRaw),
                  let label = dict["label"] as? String else {
                return nil
            }
            switch kind {
            case .window:
                return UsageRow(
                    kind: .window,
                    label: label,
                    used: (dict["used"] as? NSNumber)?.doubleValue,
                    cap: (dict["cap"] as? NSNumber)?.doubleValue,
                    resetAt: (dict["resetAt"] as? NSNumber).map { Date(timeIntervalSince1970: $0.doubleValue / 1000) }
                )
            case .balance:
                return UsageRow(
                    kind: .balance,
                    label: label,
                    balance: (dict["balance"] as? NSNumber)?.doubleValue,
                    unit: dict["unit"] as? String
                )
            }
        }
    }
}
