import Foundation

public protocol UsageProvider: Sendable {
    var config: ProviderConfig { get }
    func fetch() async throws -> UsageSnapshot
}
