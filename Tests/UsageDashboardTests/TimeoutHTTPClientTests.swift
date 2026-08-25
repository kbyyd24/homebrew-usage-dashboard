import Foundation
import Testing
@testable import UsageDashCore

private func makeRequest() -> URLRequest {
    URLRequest(url: URL(string: "https://example.com/api")!)
}

private func okResponse(_ request: URLRequest) -> (Data, HTTPURLResponse) {
    (Data("ok".utf8), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
}

@Test func returnsResultWhenInnerCompletesBeforeTimeout() async throws {
    let client = TimeoutHTTPClient(
        inner: StubHTTPClient { request in okResponse(request) },
        timeout: 1
    )

    let (data, response) = try await client.data(for: makeRequest())

    #expect(data == Data("ok".utf8))
    #expect(response.statusCode == 200)
}

@Test func throwsTimeoutWhenInnerIsSlow() async {
    let client = TimeoutHTTPClient(
        inner: StubHTTPClient { request in
            try await Task.sleep(nanoseconds: 5_000_000_000)
            return okResponse(request)
        },
        timeout: 0.1
    )

    do {
        _ = try await client.data(for: makeRequest())
        Issue.record("expected a timeout error")
    } catch let error as ProviderError {
        guard case .timeout = error else {
            Issue.record("expected timeout, got \(String(describing: error))")
            return
        }
    } catch {
        Issue.record("expected ProviderError, got \(error)")
    }
}

@Test func propagatesInnerError() async {
    let client = TimeoutHTTPClient(
        inner: StubHTTPClient { _ in throw ProviderError.parse("boom") },
        timeout: 1
    )

    do {
        _ = try await client.data(for: makeRequest())
        Issue.record("expected an error")
    } catch let error as ProviderError {
        guard case .parse = error else {
            Issue.record("expected parse, got \(String(describing: error))")
            return
        }
    } catch {
        Issue.record("expected ProviderError, got \(error)")
    }
}
