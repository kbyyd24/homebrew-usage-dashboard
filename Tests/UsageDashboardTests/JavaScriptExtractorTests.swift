import Foundation
import Testing
import UsageDashCore
@testable import UsageDashboard

private let commandCodeResponse = """
{
  "credits": { "belowThreshold": false, "creditThreshold": 0,
               "monthlyCredits": 69.4980615374, "purchasedCredits": 0, "freeCredits": 0 },
  "windowLimits": {
    "limited": true, "exceeded": null,
    "fiveHour": { "used": 0.493384528, "cap": 14, "exceeded": false, "resetAt": 1787554846343 },
    "weekly":   { "used": 0.5019384626, "cap": 35, "exceeded": false, "resetAt": 1787843213320 }
  }
}
"""

private let commandCodeExtractor = """
function(response){
  var w = response.windowLimits;
  return {
    status: "ok",
    message: "",
    rows: [
      { kind: "window", label: "5 小时", used: w.fiveHour.used, cap: w.fiveHour.cap, resetAt: w.fiveHour.resetAt },
      { kind: "window", label: "本周", used: w.weekly.used, cap: w.weekly.cap, resetAt: w.weekly.resetAt },
      { kind: "balance", label: "月度余额", balance: response.credits.monthlyCredits, unit: "credits" }
    ]
  };
}
"""

@Test func jsExtractorParsesCommandCodeIntoThreeRows() throws {
    // Given the real CommandCode response and extractor
    let extractor = JavaScriptCoreExtractor()

    // When running the extractor
    let output = try extractor.run(source: commandCodeExtractor, responseJSON: commandCodeResponse)

    // Then three rows are produced: 5h window, weekly window, monthly balance
    #expect(output.status == "ok")
    #expect(output.rows.count == 3)

    let fiveHour = output.rows[0]
    #expect(fiveHour.kind == .window)
    #expect(fiveHour.label == "5 小时")
    #expect(fiveHour.used == 0.493384528)
    #expect(fiveHour.cap == 14)
    #expect(fiveHour.resetAt?.timeIntervalSince1970 == 1_787_554_846.343)

    let weekly = output.rows[1]
    #expect(weekly.label == "本周")
    #expect(weekly.used == 0.5019384626)
    #expect(weekly.cap == 35)
    #expect(weekly.resetAt?.timeIntervalSince1970 == 1_787_843_213.320)

    let balance = output.rows[2]
    #expect(balance.kind == .balance)
    #expect(balance.label == "月度余额")
    #expect(balance.balance == 69.4980615374)
    #expect(balance.unit == "credits")
}

@Test func jsExtractorReportsErrorStatus() throws {
    // Given an extractor that reports an error status
    let extractor = JavaScriptCoreExtractor()
    let source = "function(r){ return { status: 'error', message: 'quota lookup failed', rows: [] }; }"

    // When running the extractor
    let output = try extractor.run(source: source, responseJSON: "{}")

    // Then the error status and message pass through
    #expect(output.status == "error")
    #expect(output.message == "quota lookup failed")
}

@Test func jsExtractorThrowsWhenScriptThrows() {
    // Given an extractor that throws a JS error
    let extractor = JavaScriptCoreExtractor()
    let source = "function(r){ throw new Error('kaboom'); }"

    // When & Then running surfaces an extractor error
    #expect(throws: ProviderError.self) {
        try extractor.run(source: source, responseJSON: "{}")
    }
}

@Test func jsExtractorThrowsWhenReturnIsNotAnObject() {
    // Given an extractor that returns a scalar instead of an object
    let extractor = JavaScriptCoreExtractor()
    let source = "function(r){ return 42; }"

    // When & Then running surfaces an invalid-structure error
    #expect(throws: ProviderError.self) {
        try extractor.run(source: source, responseJSON: "{}")
    }
}

@MainActor
@Test func storeObservableNotifiesOnUpdate() async throws {
    // Given a store bridged into an observable object
    let store = SnapshotStore()
    let observable = StoreObservable(store: store)
    let before = observable.revision

    // When a snapshot is updated on the store
    store.update(.ok(providerId: "p", rows: []))

    // Then the observable revision increments on the main actor
    try await Task.sleep(nanoseconds: 50_000_000)
    #expect(observable.revision == before + 1)
}
