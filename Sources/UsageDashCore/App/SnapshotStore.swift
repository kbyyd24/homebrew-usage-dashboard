import Foundation

public final class SnapshotStore: @unchecked Sendable {
    private var snapshots: [String: UsageSnapshot] = [:]
    private var handlers: [(String) -> Void] = []
    private let lock = NSLock()

    public init() {}

    public func snapshot(forId id: String) -> UsageSnapshot? {
        lock.lock()
        defer { lock.unlock() }
        return snapshots[id]
    }

    public func update(_ snapshot: UsageSnapshot) {
        let toNotify = withLock {
            snapshots[snapshot.providerId] = snapshot
            return handlers
        }
        for handler in toNotify {
            handler(snapshot.providerId)
        }
    }

    public func markError(providerId: String, message: String) {
        guard let existing = snapshot(forId: providerId) else { return }
        let toNotify = withLock {
            snapshots[providerId] = existing.markingError(message)
            return handlers
        }
        for handler in toNotify {
            handler(providerId)
        }
    }

    public func onChange(_ handler: @escaping (String) -> Void) {
        withLock {
            handlers.append(handler)
        }
    }

    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}
