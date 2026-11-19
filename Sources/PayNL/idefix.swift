import Foundation
import HTTP
import Primitives

public extension PayNL {
    enum Idefix {
        public struct Credentials: Sendable {
            public let username: Secret
            public let password: Secret

            public init(username: Secret, password: Secret) {
                self.username = username
                self.password = password
            }
        }

        public struct Transaction: Sendable, Decodable {
            public struct ID: CodableInvariant, Sendable, Hashable {
                public let raw: String

                public init(_ raw: String) throws(InvarianceFailure) {
                    try Invariance([.text.nonblank]).require(raw)
                    self.raw = raw
                }
            }

            public let id: ID
            public let description: String?
            public let reference: String?
            public let amount: Amount?
            public let status: Status?
            public let amountRefunded: Amount?
            public let orderId: String?
            public let createdAt: String?
            public let completedDate: String?

            /// Describes the literal value returned in the `id` field. This is
            /// not an assertion that an order ID and an EX transaction ID are
            /// interchangeable or that either matches a prior browse record.
            public enum IDRepresentation: String, Codable, Sendable {
                case ex_code
                case order_id
                case other
            }

            public var idRepresentation: IDRepresentation {
                if let orderId, !orderId.isEmpty, id.raw == orderId { return .order_id }
                if id.raw.hasPrefix("EX-") { return .ex_code }
                return .other
            }

            public struct Status: Decodable, Sendable {
                public let code: Int?
                public let action: String?
                public let phase: String?
            }
        }

        public struct Summary: Decodable, Sendable {
            public let id: Transaction.ID
            public let orderId: String?
            public let description: String?
            public let reference: String?
            public let amount: Amount?
            public let status: Transaction.Status?
            public let amountRefunded: Amount?
            public let createdAt: String?
            public let completedDate: String?
        }

        public struct SearchTerm: Invariant, Sendable {
            public let raw: String

            public init(_ raw: String) throws(InvarianceFailure) {
                try Invariance([.text.nonblank]).require(raw)
                self.raw = raw
            }
        }

        public struct Filter: Sendable {
            public let id: Transaction.ID?
            public let amount: Int64?

            public init(id: Transaction.ID? = nil, amount: Int64? = nil) {
                self.id = id
                self.amount = amount
            }

            fileprivate var query: [URLQueryItem] {
                var result: [URLQueryItem] = []
                if let id { result.append(.init(name: "id[eq]", value: id.raw)) }
                if let amount { result.append(.init(name: "amount[eq]", value: String(amount))) }
                return result
            }
        }

        public struct Page: Decodable, Sendable {
            public let total: Int
            public let count: Int
            public let pages: Int?
            public let transactions: [Summary]

            private struct Fields: Decodable {
                let total: Int
                let count: Int
                let pages: Int?
                let transactions: [Summary]
            }

            public init(from decoder: Decoder) throws {
                let fields = try Fields(from: decoder)
                total = fields.total
                count = fields.count
                pages = fields.pages
                transactions = fields.transactions
                guard total >= 0, count >= 0, pages.map({ $0 >= 0 }) ?? true else {
                    throw PayNL.Failure.invalidResponse
                }
            }
        }

        public actor Client {
            private let credentials: Credentials
            private let transport: Transport

            public init(credentials: Credentials, transport: Transport = .live) {
                self.credentials = credentials
                self.transport = transport
            }

            public nonisolated var transactions: Transactions { Transactions(client: self) }

            fileprivate func execute<T: Decodable & Sendable>(
                path: String, query: [URLQueryItem], as type: T.Type
            ) async throws -> T {
                let request = try PayNL.request(
                    host: "rest.pay.nl", prefix: "/v2",
                    endpoint: HTTPEndpoint(method: .get, path: path),
                    authentication: PayNL.basic(username: credentials.username, password: credentials.password),
                    query: query
                )
                return try await PayNL.perform(request, transport: transport, as: type)
            }
        }

        public struct Transactions: Sendable {
            fileprivate let client: Client

            public func list(
                page: PageNumber = .first,
                limit: PageLimit = .standard,
                filter: Filter = .init()
            ) async throws -> Page {
                try await client.execute(
                    path: "/transactions",
                    query: [
                        URLQueryItem(name: "page", value: String(page.raw)),
                        URLQueryItem(name: "limit", value: String(limit.raw)),
                    ] + filter.query,
                    as: Page.self
                )
            }

            public func find(_ needle: SearchTerm) async throws -> Page {
                try await client.execute(
                    path: "/transactions/find",
                    query: [URLQueryItem(name: "needle[eq]", value: needle.raw)],
                    as: Page.self
                )
            }

            public func get(_ id: Transaction.ID) async throws -> Transaction {
                try await client.execute(
                    path: "/transactions/\(PayNL.encoded(id.raw))",
                    query: [], as: Transaction.self
                )
            }
        }
    }
}
