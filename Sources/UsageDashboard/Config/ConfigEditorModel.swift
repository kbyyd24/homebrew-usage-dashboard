import Combine
import Foundation
import UsageDashCore

@MainActor
final class ConfigEditorModel: ObservableObject {
    struct EditableProvider: Identifiable, Equatable {
        var id: String
        var type: ProviderType
        var name: String
        var apiKeyEnvName: String
        var apiKeyLiteral: String
        var refreshIntervalSec: Int?
        var url: String
        var method: String
        var headersText: String
        var body: String
        var extractor: String

        var isCustom: Bool { type == .custom }

        init(
            id: String = "",
            type: ProviderType = .kimi,
            name: String = "",
            apiKeyEnvName: String = "",
            apiKeyLiteral: String = "",
            refreshIntervalSec: Int? = nil,
            url: String = "",
            method: String = "GET",
            headersText: String = "",
            body: String = "",
            extractor: String = ""
        ) {
            self.id = id
            self.type = type
            self.name = name
            self.apiKeyEnvName = apiKeyEnvName
            self.apiKeyLiteral = apiKeyLiteral
            self.refreshIntervalSec = refreshIntervalSec
            self.url = url
            self.method = method
            self.headersText = headersText
            self.body = body
            self.extractor = extractor
        }
    }

    @Published var defaultIntervalSec: Int = 600
    @Published var providers: [EditableProvider] = []
    @Published var errorMessage: String?
    @Published private(set) var testSnapshots: [String: UsageSnapshot] = [:]

    private let coordinator: UsageCoordinator
    private let environment: [String: String]

    init(
        coordinator: UsageCoordinator,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        self.coordinator = coordinator
        self.environment = environment
    }

    // MARK: - Loading and editing

    func load(config: AppConfig) {
        defaultIntervalSec = config.defaultIntervalSec
        providers = config.providers.map { provider in
            let envName = provider.apiKeyEnv ?? ""
            let custom = provider.custom
            return EditableProvider(
                id: provider.id,
                type: provider.type,
                name: provider.name,
                apiKeyEnvName: envName,
                apiKeyLiteral: envName.isEmpty ? (provider.apiKey ?? "") : "",
                refreshIntervalSec: provider.refreshIntervalSec,
                url: custom?.url ?? "",
                method: custom?.method ?? "GET",
                headersText: Self.formatHeaders(custom?.headers ?? [:]),
                body: custom?.body ?? "",
                extractor: custom?.extractor ?? ""
            )
        }
        errorMessage = nil
        testSnapshots = [:]
    }

    func addProvider(type: ProviderType) {
        providers = providers + [EditableProvider(type: type)]
    }

    func removeProvider(id: String) {
        providers = providers.filter { $0.id != id }
    }

    func removeProvider(at index: Int) {
        guard providers.indices.contains(index) else { return }
        var updated = providers
        updated.remove(at: index)
        providers = updated
    }

    // MARK: - Validation

    func validate() -> String? {
        if providers.isEmpty {
            return "至少需要一个订阅"
        }
        var seen = Set<String>()
        for provider in providers {
            let id = provider.id.trimmingCharacters(in: .whitespacesAndNewlines)
            if id.isEmpty {
                return "订阅 ID 不能为空"
            }
            if seen.contains(id) {
                return "订阅 ID 重复：\(id)"
            }
            seen.insert(id)

            if provider.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return "订阅「\(id)」名称不能为空"
            }
            let hasKey = !provider.apiKeyEnvName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || !provider.apiKeyLiteral.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            if !hasKey {
                return "订阅「\(id)」需要密钥（字面量或环境变量名）"
            }
            if provider.isCustom {
                if provider.url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return "订阅「\(id)」需要请求 URL"
                }
                if provider.extractor.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return "订阅「\(id)」需要 extractor 脚本"
                }
            }
        }
        return nil
    }

    // MARK: - Conversion

    func buildConfig() -> AppConfig {
        AppConfig(defaultIntervalSec: defaultIntervalSec, providers: providers.map(makeProviderConfig))
    }

    func makeProviderConfig(_ provider: EditableProvider) -> ProviderConfig {
        let envName = provider.apiKeyEnvName.trimmingCharacters(in: .whitespacesAndNewlines)
        let literal = provider.apiKeyLiteral.trimmingCharacters(in: .whitespacesAndNewlines)
        var custom: CustomQueryConfig?
        if provider.isCustom {
            custom = CustomQueryConfig(
                url: provider.url.trimmingCharacters(in: .whitespacesAndNewlines),
                method: provider.method.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? "GET" : provider.method.trimmingCharacters(in: .whitespacesAndNewlines),
                headers: Self.parseHeaders(provider.headersText),
                body: provider.body.isEmpty ? nil : provider.body,
                extractor: provider.extractor
            )
        }
        return ProviderConfig(
            id: provider.id.trimmingCharacters(in: .whitespacesAndNewlines),
            type: provider.type,
            name: provider.name.trimmingCharacters(in: .whitespacesAndNewlines),
            apiKeyEnv: envName.isEmpty ? nil : envName,
            apiKey: envName.isEmpty ? (literal.isEmpty ? nil : literal) : nil,
            refreshIntervalSec: provider.refreshIntervalSec,
            custom: custom
        )
    }

    // MARK: - Save

    func save(to url: URL) async {
        if let message = validate() {
            errorMessage = message
            return
        }
        let config = buildConfig()
        do {
            try ConfigWriter.save(config, to: url)
            await coordinator.reload(config: config)
            errorMessage = nil
        } catch {
            errorMessage = ConfigError.describe(error)
        }
    }

    // MARK: - Test connection

    func testConnection(for id: String) async {
        guard let provider = providers.first(where: { $0.id == id }) else { return }
        let trimmedId = provider.id.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedId.isEmpty {
            testSnapshots[id] = .error(providerId: id, message: "请先填写订阅 ID")
            return
        }

        var resolved = makeProviderConfig(provider)
        if let envName = resolved.apiKeyEnv {
            guard let value = environment[envName], !value.isEmpty else {
                testSnapshots[id] = .error(providerId: id, message: "环境变量 \(envName) 未设置")
                return
            }
            resolved = ProviderConfig(
                id: resolved.id,
                type: resolved.type,
                name: resolved.name,
                apiKeyEnv: envName,
                apiKey: value,
                refreshIntervalSec: resolved.refreshIntervalSec,
                custom: resolved.custom
            )
        }

        do {
            testSnapshots[id] = try await coordinator.test(provider: resolved)
        } catch {
            testSnapshots[id] = .error(providerId: id, message: ProviderError.describe(error))
        }
    }

    // MARK: - Header helpers

    static func parseHeaders(_ text: String) -> [String: String] {
        var headers: [String: String] = [:]
        for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard let colon = trimmed.firstIndex(of: ":") else { continue }
            let key = String(trimmed[..<colon]).trimmingCharacters(in: .whitespaces)
            let value = String(trimmed[trimmed.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
            if !key.isEmpty {
                headers[key] = value
            }
        }
        return headers
    }

    static func formatHeaders(_ headers: [String: String]) -> String {
        headers.map { "\($0.key): \($0.value)" }.sorted().joined(separator: "\n")
    }
}
