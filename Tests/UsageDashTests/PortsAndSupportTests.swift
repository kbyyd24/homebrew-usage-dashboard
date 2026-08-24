import Foundation
import Testing
@testable import UsageDashCore

@Test func authInjectorReplacesPlaceholder() throws {
    // Given a template containing the {{apiKey}} placeholder
    let template = "Authorization: Bearer {{apiKey}}"

    // When substituting a concrete key
    let result = try AuthInjector.substitute(template, apiKey: "sk-secret")

    // Then the placeholder is replaced
    #expect(result == "Authorization: Bearer sk-secret")
}

@Test func authInjectorLeavesTemplateWithoutPlaceholderUntouched() throws {
    // Given a template with no placeholder
    let template = "Authorization: Bearer fixed-token"

    // When substituting a key
    let result = try AuthInjector.substitute(template, apiKey: "sk-secret")

    // Then the template is returned unchanged
    #expect(result == "Authorization: Bearer fixed-token")
}

@Test func authInjectorThrowsGivenEmptyKeyAndPlaceholder() {
    // Given a template with a placeholder and an empty key
    // When & Then substitution throws a missing-api-key error
    #expect(throws: ProviderError.self) {
        try AuthInjector.substitute("Bearer {{apiKey}}", apiKey: "")
    }
}

@Test func dateParsingParsesPlainISO8601() throws {
    // Given a plain ISO8601 timestamp
    let date = try #require(DateParsing.parseISO8601("2026-08-24T12:34:56Z"))

    // When extracting components in UTC
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)

    // Then every component round-trips
    #expect(parts.year == 2026)
    #expect(parts.month == 8)
    #expect(parts.day == 24)
    #expect(parts.hour == 12)
    #expect(parts.minute == 34)
    #expect(parts.second == 56)
}

@Test func dateParsingParsesFractionalISO8601() throws {
    // Given an ISO8601 timestamp with fractional seconds
    let date = try #require(DateParsing.parseISO8601("2026-08-24T12:00:00.123Z"))

    // Then it parses to a finite date near the expected instant
    let interval = date.timeIntervalSince1970
    #expect(abs(interval - 1_787_572_800.123) < 0.001)
}

@Test func dateParsingParsesMilliseconds() {
    // Given a millisecond timestamp
    let date = DateParsing.parseMilliseconds(1_787_554_846.0 * 1000)

    // Then it maps to the equivalent seconds-based instant
    #expect(date.timeIntervalSince1970 == 1_787_554_846.0)
}
