import Foundation
import Testing
@testable import UsageDashCore

private struct FakeProvider: UsageProvider {
    let config: ProviderConfig
    let handler: @Sendable () async throws -> UsageSnapshot

    func fetch() async throws -> UsageSnapshot {
        try await handler()
    }
}

private func makeConfig(id: String, interval: Int? = nil) -> ProviderConfig {
    ProviderConfig(id: id, type: .kimi, name: id, apiKey: "x", refreshIntervalSec: interval)
}

@Test func storeUpdatesReadsAndNotifies() {
    // Given an empty store with a change handler
    let store = SnapshotStore()
    var notified: [String] = []
    store.onChange { notified.append($0) }
    #expect(store.snapshot(forId: "p") == nil)

    // When a snapshot is updated
    let snapshot = UsageSnapshot.ok(providerId: "p", rows: [UsageRow(kind: .balance, label: "余额", balance: 5)])
    store.update(snapshot)

    // Then it can be read back and the handler was notified once
    #expect(store.snapshot(forId: "p") == snapshot)
    #expect(notified == ["p"])
}

@Test func refreshOnceUpdatesStoreOnSuccess() async {
    // Given a scheduler over a provider that succeeds
    let store = SnapshotStore()
    let provider = FakeProvider(config: makeConfig(id: "p")) {
        .ok(providerId: "p", rows: [UsageRow(kind: .window, label: "5 小时", used: 1, cap: 14)])
    }
    let scheduler = RefreshScheduler(store: store, providers: [provider])

    // When refreshing once
    await scheduler.refreshOnce(provider)

    // Then the store holds a successful snapshot
    let snapshot = store.snapshot(forId: "p")
    #expect(snapshot?.status == .ok)
    #expect(snapshot?.rows.count == 1)
}

@Test func refreshOnceKeepsOldDataAndMarksErrorOnFailure() async {
    // Given a store that already holds a good snapshot and a provider that now fails
    let store = SnapshotStore()
    let old = UsageSnapshot.ok(providerId: "p", rows: [UsageRow(kind: .window, label: "本周", used: 2, cap: 10)])
    store.update(old)
    let provider = FakeProvider(config: makeConfig(id: "p")) {
        throw ProviderError.http(status: 500, body: "boom")
    }
    let scheduler = RefreshScheduler(store: store, providers: [provider])

    // When refreshing once
    await scheduler.refreshOnce(provider)

    // Then old rows are preserved and the status becomes an error
    let snapshot = store.snapshot(forId: "p")
    #expect(snapshot?.status == .error)
    #expect(snapshot?.rows == old.rows)
    #expect(snapshot?.message == "http 500: boom")
}

@Test func refreshOnceCreatesErrorSnapshotWhenNoOldData() async {
    // Given an empty store and a provider that fails
    let store = SnapshotStore()
    let provider = FakeProvider(config: makeConfig(id: "p")) {
        throw ProviderError.parse("bad shape")
    }
    let scheduler = RefreshScheduler(store: store, providers: [provider])

    // When refreshing once
    await scheduler.refreshOnce(provider)

    // Then an error snapshot is created with no rows
    let snapshot = store.snapshot(forId: "p")
    #expect(snapshot?.status == .error)
    #expect(snapshot?.rows.isEmpty == true)
    #expect(snapshot?.message == "parse error: bad shape")
}

@Test func intervalFallsBackToDefault() {
    // Given one provider with an explicit interval and one without
    let store = SnapshotStore()
    let override = FakeProvider(config: makeConfig(id: "a", interval: 120)) { .ok(providerId: "a", rows: []) }
    let plain = FakeProvider(config: makeConfig(id: "b")) { .ok(providerId: "b", rows: []) }
    let scheduler = RefreshScheduler(store: store, providers: [override, plain], defaultInterval: 600)

    // Then the override wins and the default is used otherwise
    #expect(scheduler.interval(for: override) == 120)
    #expect(scheduler.interval(for: plain) == 600)
}
