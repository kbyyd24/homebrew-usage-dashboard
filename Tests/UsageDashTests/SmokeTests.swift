import Testing
@testable import UsageDashCore

@Test func smokeCoreLibraryIsPresent() {
    // Given a freshly built package

    // When the core library is imported

    // Then its placeholder version marker is visible
    #expect(UsageDashCore.version == "0.1.0")
}
