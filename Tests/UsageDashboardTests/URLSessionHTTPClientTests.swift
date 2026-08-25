import Foundation
import Testing
@testable import UsageDashCore

@Suite(.serialized)
struct URLSessionHTTPClientTests {
    private static func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }

    @Test func returnsDataAndResponse() async throws {
        // Given a mocked 200 response with a known body
        MockURLProtocol.requestHandler = { request in
            #expect(request.url?.absoluteString == "https://example.com/usages")
            #expect(request.httpMethod == "GET")
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data("hello".utf8))
        }
        let client = URLSessionHTTPClient(session: Self.makeSession())

        // When issuing the request
        let (data, response) = try await client.data(for: URLRequest(url: URL(string: "https://example.com/usages")!))

        // Then the body and status are returned unchanged
        #expect(data == Data("hello".utf8))
        #expect(response.statusCode == 200)
    }

    @Test func returnsNon200WithoutThrowing() async throws {
        // Given a mocked 503 response
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 503, httpVersion: nil, headerFields: nil)!
            return (response, Data("err".utf8))
        }
        let client = URLSessionHTTPClient(session: Self.makeSession())

        // When issuing the request
        let (data, response) = try await client.data(for: URLRequest(url: URL(string: "https://example.com/x")!))

        // Then the client does not translate status codes into errors
        #expect(response.statusCode == 503)
        #expect(data == Data("err".utf8))
    }

    @Test func usesInjectedSession() async throws {
        // Given a client built over a custom session whose mock records the request
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["X-Seen": "yes"])!
            return (response, Data("ok".utf8))
        }
        let client = URLSessionHTTPClient(session: Self.makeSession())

        // When issuing a request with a custom header
        var request = URLRequest(url: URL(string: "https://example.com/injected")!)
        request.setValue("Bearer token", forHTTPHeaderField: "Authorization")
        let (_, response) = try await client.data(for: request)

        // Then the injected session processed it
        #expect(response.statusCode == 200)
    }
}

private final class MockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
