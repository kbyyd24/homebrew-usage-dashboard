import Foundation
import Testing
@testable import UsageDashCore

private let utc = TimeZone(identifier: "UTC")!

@Test func displaysWindowRowsWithUsedCapPercentAndReset() {
    // Given a config and an ok snapshot with two window rows
    let config = ProviderConfig(id: "kimi", type: .kimi, name: "Kimi Code")
    let snapshot = UsageSnapshot.ok(
        providerId: "kimi",
        rows: [
            UsageRow(kind: .window, label: "5 小时", used: 1, cap: 14, resetAt: Date(timeIntervalSince1970: 1_787_572_800)),
            UsageRow(kind: .window, label: "本周", used: 40, cap: 100, resetAt: Date(timeIntervalSince1970: 1_788_048_000)),
        ]
    )
    let store = SnapshotStore()
    store.update(snapshot)
    let viewModel = DashboardViewModel(configs: [config], store: store, timeZone: utc)

    // When producing the display model
    let providers = viewModel.display()

    // Then each provider exposes its name, status, and formatted window rows
    #expect(providers.count == 1)
    let provider = providers[0]
    #expect(provider.id == "kimi")
    #expect(provider.name == "Kimi Code")
    #expect(provider.status == .ok)
    #expect(provider.errorMessage == nil)

    let fiveHour = provider.rows[0]
    #expect(fiveHour.label == "5 小时")
    #expect(fiveHour.usedText == "1")
    #expect(fiveHour.capText == "14")
    #expect(fiveHour.percentText == "7%")
    #expect(fiveHour.resetText == "2026-08-24 12:00")
    #expect(fiveHour.progress == 1.0 / 14.0)

    let weekly = provider.rows[1]
    #expect(weekly.percentText == "40%")
    #expect(weekly.resetText == "2026-08-30 00:00")
    #expect(weekly.progress == 0.4)
}

@Test func displaysBalanceRowsWithUnitAndFetchTime() {
    // Given a config and an ok snapshot with a balance row
    let config = ProviderConfig(id: "cc", type: .custom, name: "CommandCode")
    let fetchedAt = Date(timeIntervalSince1970: 1_787_572_800)
    let snapshot = UsageSnapshot.ok(
        providerId: "cc",
        rows: [UsageRow(kind: .balance, label: "月度余额", balance: 69.498, unit: "credits")],
        fetchedAt: fetchedAt
    )
    let store = SnapshotStore()
    store.update(snapshot)
    let viewModel = DashboardViewModel(configs: [config], store: store, timeZone: utc)

    // When producing the display model
    let row = viewModel.display()[0].rows[0]

    // Then the balance row carries formatted value, unit, and no reset info
    #expect(row.label == "月度余额")
    #expect(row.balanceText == "69.5")
    #expect(row.unit == "credits")
    #expect(row.resetText == nil)
    #expect(row.progress == nil)
    #expect(viewModel.display()[0].fetchedAtText == "12:00:00")
}

@Test func displaysErrorAndIdleStates() {
    // Given an error snapshot for one provider and no snapshot for another
    let failing = ProviderConfig(id: "a", type: .kimi, name: "A")
    let idle = ProviderConfig(id: "b", type: .minimax, name: "B")
    let store = SnapshotStore()
    store.update(.error(providerId: "a", message: "http 500: boom"))
    let viewModel = DashboardViewModel(configs: [failing, idle], store: store, timeZone: utc)

    // When producing the display model
    let providers = viewModel.display()

    // Then statuses and error messages are surfaced
    #expect(providers.count == 2)
    #expect(providers[0].status == .error)
    #expect(providers[0].errorMessage == "http 500: boom")
    #expect(providers[0].rows.isEmpty)
    #expect(providers[1].status == .idle)
    #expect(providers[1].errorMessage == nil)
    #expect(providers[1].rows.isEmpty)
}
