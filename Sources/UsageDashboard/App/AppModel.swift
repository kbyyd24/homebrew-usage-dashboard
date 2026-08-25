import Combine
import UsageDashCore

@MainActor
final class AppModel: ObservableObject {
    let coordinator: UsageCoordinator
    let observable: StoreObservable
    let editorModel: ConfigEditorModel

    @Published private(set) var configError: String?
    @Published private(set) var configWarnings: [String] = []
    @Published var isConfigEditorPresented = false

    init() {
        let coordinator = UsageCoordinator(
            httpClient: URLSessionHTTPClient(),
            extractorRunner: JavaScriptCoreExtractor()
        )
        self.coordinator = coordinator
        self.observable = StoreObservable(store: coordinator.store)
        self.editorModel = ConfigEditorModel(coordinator: coordinator)
    }

    var dashboard: DashboardViewModel {
        coordinator.dashboard ?? DashboardViewModel(configs: [], store: coordinator.store)
    }

    func start() async {
        await coordinator.start()
        configError = coordinator.configError
        configWarnings = coordinator.configWarnings
    }

    func presentConfigEditor() {
        if let config = coordinator.config {
            editorModel.load(config: config)
        }
        isConfigEditorPresented = true
    }

    func saveConfig() async {
        guard let url = coordinator.configURL else { return }
        await editorModel.save(to: url)
        configError = coordinator.configError
        configWarnings = coordinator.configWarnings
        if editorModel.errorMessage == nil {
            isConfigEditorPresented = false
        }
    }
}
