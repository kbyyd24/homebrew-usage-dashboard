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
            let loader = ConfigLoader(environment: environment)
            let url = configURL ?? ConfigPath.resolve(environment: environment)
            let config = try loader.load(url: url)
            assemble(config)
            await scheduler?.refreshAllOnce()
            scheduler?.start()
        } catch {
            configError = ConfigError.describe(error)
        }
    }

    private func assemble(_ config: AppConfig) {
        configWarnings = config.warnings
        let providers = config.providers.map(buildProvider)
        let scheduler = RefreshScheduler(store: store, providers: providers, defaultInterval: config.defaultIntervalSec)
        self.scheduler = scheduler
        self.dashboard = DashboardViewModel(configs: config.providers, store: store)
    }

    private func buildProvider(_ config: ProviderConfig) -> UsageProvider {
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
