import Foundation
import HTTP
import Primitives

public extension PayNL {
    enum TGU {
        public enum Environment: String, Sendable {
            case test
            case prod
        }

        public enum Credentials: Sendable {
            case basic(username: Secret, password: Secret)
            case bearer(Secret)

            fileprivate var authorization: String {
                switch self {
                case .basic(let username, let password):
                    PayNL.basic(username: username, password: password)
                case .bearer(let token):
                    "Bearer \(token.raw)"
                }
            }
        }

        public actor Client {
            private let credentials: Credentials
            private let environment: Environment
            private let transport: Transport

            public init(
                credentials: Credentials,
                environment: Environment = .prod,
                transport: Transport = .live
            ) {
                self.credentials = credentials
                self.environment = environment
                self.transport = transport
            }

            public nonisolated var orders: Orders { Orders(client: self) }

            fileprivate func execute<T: Decodable & Sendable>(
                endpoint: HTTPEndpoint,
                body: Data? = nil,
                as type: T.Type
            ) async throws -> T {
                var request = try PayNL.request(
                    host: "connect.pay.nl",
                    prefix: "",
                    endpoint: endpoint,
                    authentication: credentials.authorization,
                    body: body
                )
                request.setValue(environment.rawValue, forHTTPHeaderField: "Pay-Environment")
                return try await PayNL.perform(request, transport: transport, as: type)
            }
        }

        public struct Orders: Sendable {
            fileprivate let client: Client

            public func create(_ input: Order.Input) async throws -> Order {
                let body = try JSONEncoder().encode(input)
                let order: Order = try await client.execute(
                    endpoint: HTTPEndpoint(method: .post, path: "/v2/orders"),
                    body: body,
                    as: Order.self
                )
                try order.validateForCreate(input)
                return order
            }

            public func status(_ id: Order.ID) async throws -> Order {
                let order: Order = try await client.execute(
                    endpoint: HTTPEndpoint(
                        method: .get,
                        path: "/v2/orders/\(PayNL.encoded(id.raw))/status"
                    ),
                    as: Order.self
                )
                guard order.id == id, order.status?.isIdentified == true else {
                    throw PayNL.Failure.invalidResponse
                }
                return order
            }
        }
    }
}
