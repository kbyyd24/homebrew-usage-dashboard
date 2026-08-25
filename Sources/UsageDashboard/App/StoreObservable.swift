import Combine
import UsageDashCore

@MainActor
public final class StoreObservable: ObservableObject {
    @Published public private(set) var revision: Int = 0
    public let store: SnapshotStore

    public init(store: SnapshotStore) {
        self.store = store
        store.onChange { [weak self] _ in
            Task { @MainActor in
                self?.revision += 1
            }
        }
    }
}
