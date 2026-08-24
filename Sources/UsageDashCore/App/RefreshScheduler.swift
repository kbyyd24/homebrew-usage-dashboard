import Foundation

public struct RefreshInterval: Hashable, Sendable {
    public let seconds: Int

    public init(configured: Int?, defaultSeconds: Int = 600) {
        self.seconds = configured ?? defaultSeconds
    }
}

public final class RefreshScheduler: @unchecked Sendable {
    public let store: SnapshotStore
    private let providers: [UsageProvider]
    private let defaultInterval: Int
    private var tasks: [Task<Void, Never>] = []

    public init(store: SnapshotStore, providers: [UsageProvider], defaultInterval: Int = 600) {
        self.store = store
        self.providers = providers
        self.defaultInterval = defaultInterval
    }

    public func interval(for provider: UsageProvider) -> Int {
        RefreshInterval(configured: provider.config.refreshIntervalSec, defaultSeconds: defaultInterval).seconds
    }

    public func refreshOnce(_ provider: UsageProvider) async {
        do {
            let snapshot = try await provider.fetch()
            store.update(snapshot)
        } catch {
            let message = ProviderError.describe(error)
            if store.snapshot(forId: provider.config.id) == nil {
                store.update(.error(providerId: provider.config.id, message: message))
            } else {
                store.markError(providerId: provider.config.id, message: message)
            }
        }
    }

    public func refreshAllOnce() async {
        for provider in providers {
            await refreshOnce(provider)
        }
    }

    public func start() {
        guard tasks.isEmpty else { return }
        tasks = providers.map { provider in
            Task { [weak self] in
                guard let self else { return }
                while !Task.isCancelled {
                    let seconds = self.interval(for: provider)
                    if seconds > 0 {
                        try? await Task.sleep(nanoseconds: UInt64(seconds) * 1_000_000_000)
                    }
                    if Task.isCancelled { return }
                    await self.refreshOnce(provider)
                }
            }
        }
    }

    public func stop() {
        tasks.forEach { $0.cancel() }
        tasks = []
    }
}
