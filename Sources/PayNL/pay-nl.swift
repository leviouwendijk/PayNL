import Foundation
import HTTP
import Primitives
import Sensitivity
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum PayNL {}

public extension PayNL {
    struct Secret: Invariant, Sendable, Sensitivity.Redacted {
        public static let redactedLabel = "PAY. credential"

        public let raw: String

        public init(_ raw: String) throws(InvarianceFailure) {
            try Invariance([.text.nonblank]).require(raw)
            self.raw = raw
        }
    }

    struct PageNumber: CodableInvariant, Sendable, Hashable {
        public let raw: Int

        public init(_ raw: Int) throws(InvarianceFailure) {
            try Invariance([.range.min(1)]).require(raw)
            self.raw = raw
        }

        public static let first = Self(unchecked: 1)
        private init(unchecked: Int) { raw = unchecked }
    }

    struct PageLimit: CodableInvariant, Sendable, Hashable {
        public let raw: Int

        public init(_ raw: Int) throws(InvarianceFailure) {
            try Invariance([.range.min(1), .range.max(100)]).require(raw)
            self.raw = raw
        }

        public static let standard = Self(unchecked: 100)
        private init(unchecked: Int) { raw = unchecked }
    }

    enum Failure: Error, Sendable, Equatable {
        case invalidResponse
        case invalidTransportResponse
        case http(status: Int)
    }

    struct Transport: Sendable {
        public let send: @Sendable (URLRequest) async throws -> (Data, HTTPURLResponse)

        public init(send: @escaping @Sendable (URLRequest) async throws -> (Data, HTTPURLResponse)) {
            self.send = send
        }

        public static let live = Self { request in
            let (data, response) = try await VerifiedSession.client.data(for: request)
            guard let response = response as? HTTPURLResponse else {
                throw Failure.invalidTransportResponse
            }
            return (data, response)
        }
    }

    struct Amount: Decodable, Sendable {
        public let value: Int64
        public let currency: Currency?
    }
}

extension PayNL {
    static func encoded(_ raw: String) throws -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        guard let encoded = raw.addingPercentEncoding(withAllowedCharacters: allowed) else {
            throw Failure.invalidResponse
        }
        return encoded
    }

    static func request(
        host: String,
        prefix: String,
        endpoint: HTTPEndpoint,
        authentication: String,
        query: [URLQueryItem] = [],
        body: Data? = nil
    ) throws -> URLRequest {
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.percentEncodedPath = prefix + endpoint.path
        if !query.isEmpty { components.queryItems = query }
        guard let url = components.url else { throw Failure.invalidResponse }
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("PayNLSwiftSDK/0.1", forHTTPHeaderField: "User-Agent")
        request.setValue(authentication, forHTTPHeaderField: "Authorization")
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return request
    }

    static func perform<T: Decodable & Sendable>(
        _ request: URLRequest,
        transport: Transport,
        as type: T.Type
    ) async throws -> T {
        let (data, response) = try await transport.send(request)
        guard (200..<300).contains(response.statusCode) else {
            if let problem = APIError.decode(status: response.statusCode, from: data) {
                throw problem
            }
            throw Failure.http(status: response.statusCode)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    static func basic(username: Secret, password: Secret) -> String {
        let credentials = Data("\(username.raw):\(password.raw)".utf8).base64EncodedString()
        return "Basic \(credentials)"
    }
}

private enum VerifiedSession {
    static let client: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpShouldSetCookies = false
        configuration.httpCookieAcceptPolicy = .never
        return URLSession(configuration: configuration, delegate: BlockRedirects(), delegateQueue: nil)
    }()
}

private final class BlockRedirects: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}
