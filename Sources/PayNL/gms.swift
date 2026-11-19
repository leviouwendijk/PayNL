import Foundation
import HTTP
import Primitives

public extension PayNL {
    enum GMS {
        public enum Credentials: Sendable {
            case bearer(Secret)
            case apiToken(at_code: Secret, api_token: Secret)

            fileprivate var authorization: String {
                switch self {
                case .bearer(let token):
                    return "Bearer \(token.raw)"
                case .apiToken(let at_code, let api_token):
                    return PayNL.basic(username: at_code, password: api_token)
                }
            }
        }

        public struct SettlementLimit: CodableInvariant, Sendable, Hashable {
            public let raw: Int

            public init(_ raw: Int) throws(InvarianceFailure) {
                try Invariance([.range.min(1), .range.max(10)]).require(raw)
                self.raw = raw
            }

            public static let standard = Self(unchecked: 10)
            private init(unchecked: Int) { raw = unchecked }
        }

        public struct Merchant: Decodable, Sendable {
            public let code: String?
            public let name: String?
            public let status: String?
        }

        public struct TurnoverGroup: Decodable, Sendable {
            public let code: String?
            public let name: String?
        }

        public struct Clearing: Decodable, Sendable {
            public struct ID: CodableInvariant, Hashable, Sendable {
                public let raw: String

                public init(_ raw: String) throws(InvarianceFailure) {
                    try Invariance([.text.nonblank]).require(raw)
                    self.raw = raw
                }
            }

            public let id: ID
            public let settlementCode: Settlement.Code?
            public let period: String?
            public let periodType: String?
            public let clearingDate: String?
            public let status: String?
            public let merchant: Merchant?
            public let turnoverGroups: [TurnoverGroup]?
            public let rollingReserve: Amount?
            public let costs: Amount?
        }

        public struct Settlement: Decodable, Sendable {
            public struct Code: CodableInvariant, Hashable, Sendable {
                public let raw: String

                public init(_ raw: String) throws(InvarianceFailure) {
                    try Invariance([.text.nonblank]).require(raw)
                    self.raw = raw
                }
            }

            public let code: Code
            public let description: String?
            public let settlementDate: String?
            public let confirmationDate: String?
            public let amount: Amount?
            public let baseAccountIban: String?
            public let clearings: [ClearingGroup]?

            public struct ClearingGroup: Decodable, Sendable {
                public let clearingId: Clearing.ID
                public let clearingLines: [Line]?
            }

            public struct Line: Decodable, Sendable {
                public let code: String?
                public let clearingDate: String?
                public let settlementDate: String?
                public let valueDate: String?
                public let state: String?
                public let amount: Amount?
                public let transactions: Int?
                public let uniquePayers: Int?
            }
        }

        public struct ClearingLine: Decodable, Sendable {
            public let code: String
            public let releaseDate: String?
            public let turnoverDate: String?
            public let state: String?
            public let volume: Amount?
            public let transactions: Int?
            public let uniquePayers: Int?
        }

        public struct Page<Element: Sendable>: Sendable {
            public let total: Int?
            public let count: Int
            public let pages: Int
            public let items: [Element]

            init(total: Int?, count: Int, pages: Int, items: [Element]) throws {
                guard count >= 0, pages >= 0,
                      total.map({ $0 >= 0 }) ?? true,
                      count == items.count else {
                    throw PayNL.Failure.invalidResponse
                }
                self.total = total
                self.count = count
                self.pages = pages
                self.items = items
            }
        }

        private struct ClearingEnvelope: Decodable, Sendable {
            let total: Int?
            let count: Int
            let pages: Int
            let clearings: [Clearing]

            func page() throws -> Page<Clearing> {
                try Page(total: total, count: count, pages: pages, items: clearings)
            }
        }

        private struct SettlementEnvelope: Decodable, Sendable {
            let total: Int?
            let count: Int
            let pages: Int
            let settlements: [Settlement]

            func page() throws -> Page<Settlement> {
                try Page(total: total, count: count, pages: pages, items: settlements)
            }
        }

        private struct LineEnvelope: Decodable, Sendable {
            let total: Int?
            let count: Int
            let pages: Int
            let clearingLines: [ClearingLine]

            func page() throws -> Page<ClearingLine> {
                try Page(total: total, count: count, pages: pages, items: clearingLines)
            }
        }

        public actor Client {
            private let credentials: Credentials
            private let transport: Transport

            public init(credentials: Credentials, transport: Transport = .live) {
                self.credentials = credentials
                self.transport = transport
            }

            public nonisolated var clearings: Clearings { Clearings(client: self) }
            public nonisolated var settlements: Settlements { Settlements(client: self) }

            func execute<T: Decodable & Sendable>(
                path: String,
                query: [URLQueryItem] = [],
                as type: T.Type
            ) async throws -> T {
                let request = try PayNL.request(
                    host: "gms.pay.nl", prefix: "",
                    endpoint: HTTPEndpoint(method: .get, path: path),
                    authentication: credentials.authorization,
                    query: query
                )
                return try await PayNL.perform(request, transport: transport, as: type)
            }
        }

        public struct Clearings: Sendable {
            fileprivate let client: Client

            public func list(
                page: PageNumber = .first,
                limit: PageLimit = .standard
            ) async throws -> Page<Clearing> {
                let response: ClearingEnvelope = try await client.execute(
                    path: "/v2/clearings",
                    query: [
                        .init(name: "page", value: String(page.raw)),
                        .init(name: "limit", value: String(limit.raw)),
                    ],
                    as: ClearingEnvelope.self
                )
                return try response.page()
            }

            public func get(_ id: Clearing.ID) async throws -> Clearing {
                let item: Clearing = try await client.execute(
                    path: "/v2/clearings/\(PayNL.encoded(id.raw))",
                    as: Clearing.self
                )
                guard item.id == id else { throw PayNL.Failure.invalidResponse }
                return item
            }

            public func lines(
                for id: Clearing.ID,
                page: PageNumber = .first
            ) async throws -> Page<ClearingLine> {
                let response: LineEnvelope = try await client.execute(
                    path: "/v2/clearings/\(PayNL.encoded(id.raw))/lines",
                    query: [.init(name: "page", value: String(page.raw))],
                    as: LineEnvelope.self
                )
                return try response.page()
            }
        }

        public struct Settlements: Sendable {
            fileprivate let client: Client

            public func list(
                page: PageNumber = .first,
                limit: SettlementLimit = .standard
            ) async throws -> Page<Settlement> {
                let response: SettlementEnvelope = try await client.execute(
                    path: "/v2/clearings/settlements",
                    query: [
                        .init(name: "page", value: String(page.raw)),
                        .init(name: "limit", value: String(limit.raw)),
                    ],
                    as: SettlementEnvelope.self
                )
                return try response.page()
            }
        }
    }
}
