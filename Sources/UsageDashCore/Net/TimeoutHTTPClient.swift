import Foundation

/// Wraps another `HTTPClient` and fails the request with `ProviderError.timeout`
/// if it does not complete within the given interval. The inner request task is
/// cancelled once the timeout fires.
public struct TimeoutHTTPClient: HTTPClient {
    private let inner: HTTPClient
    private let timeout: TimeInterval

    public init(inner: HTTPClient, timeout: TimeInterval) {
        self.inner = inner
        self.timeout = timeout
    }

    public func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        try await withThrowingTaskGroup(of: (Data, HTTPURLResponse).self) { group in
            group.addTask {
                try await inner.data(for: request)
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw ProviderError.timeout(seconds: timeout)
            }
            defer { group.cancelAll() }
            guard let result = try await group.next() else {
                throw ProviderError.timeout(seconds: timeout)
            }
            return result
        }
    }
}
