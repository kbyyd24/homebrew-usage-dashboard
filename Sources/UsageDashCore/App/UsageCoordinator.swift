import Foundation

@MainActor
public final class UsageCoordinator {
    public let store = SnapshotStore()
    public private(set) var dashboard: DashboardViewModel?
    public private(set) var configError: String?
    public private(set) var configWarnings: [String] = []

    private let httpClient: HTTPClient
    private let extractorRunner: ExtractorRunner
    private var scheduler: RefreshScheduler?

    public init(httpClient: HTTPClient = URLSessionHTTPClient(), extractorRunner: ExtractorRunner) {
        self.httpClient = httpClient
        self.extractorRunner = extractorRunner
    }

    public func start(
        configURL: URL? = nil,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) async {
        do {
            let resolved = configURL ?? ConfigPath.resolve(environment: environment)
            let url = try ConfigMigration.migrateIfNeeded(configURL: resolved, environment: environment)
            let config = try ConfigLoader(environment: environment).load(url: url)
            await reload(config: config)
        } catch {
            configError = ConfigError.describe(error)
        }
    }

    /// Re-assembles providers, scheduler, and view model from a config and
    /// refreshes once, stopping any previous scheduler first.
    public func reload(config: AppConfig) async {
        configError = nil
        scheduler?.stop()
        assemble(config)
        await scheduler?.refreshAllOnce()
        scheduler?.start()
    }

    /// Runs a single fetch for the given provider config using the injected
    /// client/extractor, wrapped in a timeout. Does not touch the store.
    public func test(provider: ProviderConfig, timeout: TimeInterval = 10) async throws -> UsageSnapshot {
        let built = buildProvider(provider, httpClient: TimeoutHTTPClient(inner: httpClient, timeout: timeout))
        return try await built.fetch()
    }

    private func assemble(_ config: AppConfig) {
        configWarnings = config.warnings
        let providers = config.providers.map { buildProvider($0, httpClient: httpClient) }
        let scheduler = RefreshScheduler(store: store, providers: providers, defaultInterval: config.defaultIntervalSec)
        self.scheduler = scheduler
        self.dashboard = DashboardViewModel(configs: config.providers, store: store)
    }

    private func buildProvider(_ config: ProviderConfig, httpClient: HTTPClient) -> UsageProvider {
        switch config.type {
        case .kimi:
            return KimiProvider(config: config, httpClient: httpClient)
        case .minimax:
            return MiniMaxProvider(config: config, httpClient: httpClient)
        case .custom:
            return CustomProvider(config: config, httpClient: httpClient, extractorRunner: extractorRunner)
        }
    }
}
