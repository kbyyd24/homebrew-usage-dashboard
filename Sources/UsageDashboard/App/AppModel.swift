import Combine
import UsageDashCore

@MainActor
final class AppModel: ObservableObject {
    let coordinator: UsageCoordinator
    let observable: StoreObservable

    @Published private(set) var configError: String?
    @Published private(set) var configWarnings: [String] = []

    init() {
        let coordinator = UsageCoordinator(
            httpClient: URLSessionHTTPClient(),
            extractorRunner: JavaScriptCoreExtractor()
        )
        self.coordinator = coordinator
        self.observable = StoreObservable(store: coordinator.store)
    }

    var dashboard: DashboardViewModel {
        coordinator.dashboard ?? DashboardViewModel(configs: [], store: coordinator.store)
    }

    func start() async {
        await coordinator.start()
        configError = coordinator.configError
        configWarnings = coordinator.configWarnings
    }
}
