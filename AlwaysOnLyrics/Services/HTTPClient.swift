import Foundation

/// Protocol for HTTP networking operations
/// Allows for easy mocking and testing
protocol HTTPClient {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

/// Default implementation using URLSession
class URLSessionHTTPClient: HTTPClient {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        return try await session.data(for: request)
    }
}
