import Foundation
import Testing
@testable import UsageDashCore

@Test func windowRowCarriesUsageFields() {
    // Given a window-style usage row
    let reset = Date(timeIntervalSince1970: 1_787_554_846.0)

    // When constructing the row
    let row = UsageRow(kind: .window, label: "5 小时", used: 0.493384528, cap: 14, resetAt: reset)

    // Then its window fields round-trip
    #expect(row.kind == .window)
    #expect(row.label == "5 小时")
    #expect(row.used == 0.493384528)
    #expect(row.cap == 14)
    #expect(row.resetAt == reset)
    #expect(row.balance == nil)
    #expect(row.unit == nil)
}

@Test func balanceRowCarriesBalanceFields() {
    // Given a balance-style usage row
    let row = UsageRow(kind: .balance, label: "月度余额", balance: 69.4980615374, unit: "credits")

    // Then its balance fields round-trip
    #expect(row.kind == .balance)
    #expect(row.label == "月度余额")
    #expect(row.balance == 69.4980615374)
    #expect(row.unit == "credits")
    #expect(row.used == nil)
    #expect(row.cap == nil)
    #expect(row.resetAt == nil)
}

@Test func usageRowIsHashableAndEquatable() {
    // Given two rows built from the same values and one built from different values
    let a = UsageRow(kind: .window, label: "周", used: 0.5, cap: 35)
    let b = UsageRow(kind: .window, label: "周", used: 0.5, cap: 35)
    let c = UsageRow(kind: .window, label: "周", used: 1.0, cap: 35)

    // Then equality and hashing reflect field values
    #expect(a == b)
    #expect(a != c)
    #expect(Set([a, b, c]).count == 2)
}

@Test func providerTypeRawValuesMatchConfig() {
    // Given the known provider type identifiers used in JSON config
    // Then raw values stay stable
    #expect(ProviderType.kimi.rawValue == "kimi")
    #expect(ProviderType.minimax.rawValue == "minimax")
    #expect(ProviderType.custom.rawValue == "custom")
}

@Test func snapshotHasOkAndErrorConvenienceForms() {
    // Given rows and a message
    let rows = [UsageRow(kind: .balance, label: "月度余额", balance: 3.0, unit: "credits")]
    let fetched = Date(timeIntervalSince1970: 1_700_000_000)

    // When building snapshots via convenience factories
    let ok = UsageSnapshot.ok(providerId: "p", rows: rows, fetchedAt: fetched)
    let error = UsageSnapshot.error(providerId: "p", message: "boom")

    // Then status/rows/message are set accordingly
    #expect(ok.status == .ok)
    #expect(ok.rows == rows)
    #expect(ok.fetchedAt == fetched)
    #expect(error.status == .error)
    #expect(error.rows.isEmpty)
    #expect(error.message == "boom")
}
