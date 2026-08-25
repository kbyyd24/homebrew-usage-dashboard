import Testing
@testable import UsageDashCore

@Test func smokeCoreLibraryIsPresent() {
    // Given a freshly built package

    // When the core library is imported

    // Then a core value type is visible (smoke marker)
    #expect(ProviderStatus.ok == .ok)
}
