import Foundation
import Primitives

public extension PayNL.TGU {
    struct Order: Decodable, Sendable {
        public struct ID: CodableInvariant, Hashable, Sendable {
            public let raw: String

            public init(_ raw: String) throws(InvarianceFailure) {
                try Invariance([.text.nonblank]).require(raw)
                self.raw = raw
            }
        }

        public struct Status: Decodable, Sendable {
            public let code: Int?
            public let name: String?
            public let action: String?

            public var isIdentified: Bool {
                code != nil || name?.isEmpty == false || action?.isEmpty == false
            }
        }

        public struct Links: Decodable, Sendable {
            public let values: [String: URL]

            public init(from decoder: Decoder) throws {
                let raw = try [String: String?](from: decoder)
                self.values = raw.compactMapValues { $0.flatMap(URL.init(string:)) }
            }

            public var status: URL? { values["status"] }
            public var checkout: URL? { values["checkout"] }
            public var redirect: URL? { values["redirect"] }
            public subscript(_ name: String) -> URL? { values[name] }
        }

        public struct Integration: Decodable, Sendable {
            public let pointOfInteraction: String?
            public let test: Bool?
        }

        public struct SplitPayment: Decodable, Sendable {
            public let serviceId: String?
            public let fee: String?
            public let amount: PayNL.Amount?
        }

        public struct Stats: Decodable, Sendable {
            public let tool: String?
            public let info: String?
            public let object: String?
            public let extra1: String?
            public let extra2: String?
            public let extra3: String?
            public let domainId: String?
            public let promotorId: Int?
        }

        public struct Payment: Decodable, Sendable {
            public struct Method: Decodable, Sendable {
                public let id: Int?
                public let input: JSONValue?
            }

            public let id: String?
            public let paymentMethod: Method?
            public let customerKey: String?
            public let customerId: String?
            public let status: Status?
            public let amount: PayNL.Amount?
            public let currencyAmount: PayNL.Amount?
            public let authorizedAmount: PayNL.Amount?
            public let capturedAmount: PayNL.Amount?
            public let recurring: Bool?
            public let externalId: String?
        }

        public enum CheckoutFailure: Error, Sendable, Equatable {
            case missingRedirect
            case invalidRedirect
        }

        public let id: ID
        public let type: String?
        public let orderId: String?
        public let uuid: String?
        public let serviceId: String?
        public let description: String?
        public let reference: String?
        public let manualTransferCode: String?
        public let customerKey: String?
        public let receipt: String?
        public let status: Status?
        public let amount: PayNL.Amount?
        public let authorizedAmount: PayNL.Amount?
        public let capturedAmount: PayNL.Amount?
        public let integration: Integration?
        public let splitPayments: [SplitPayment]?
        public let stats: Stats?
        public let transferData: JSONValue?
        public let payments: [Payment]?
        public let checkoutData: JSONValue?
        public let expiresAt: String?
        public let createdAt: String?
        public let createdBy: String?
        public let modifiedAt: String?
        public let modifiedBy: String?
        public let completedAt: String?
        public let links: Links?

        public func requireRedirectURL() throws -> URL {
            guard let url = links?.redirect else { throw CheckoutFailure.missingRedirect }
            guard url.scheme?.lowercased() == "https",
                  let host = url.host, !host.isEmpty,
                  url.user == nil, url.password == nil
            else { throw CheckoutFailure.invalidRedirect }
            return url
        }

        public func validateForCreate(_ input: Input) throws {
            guard let status, status.isIdentified else { throw PayNL.Failure.invalidResponse }
            if let serviceId, serviceId != input.serviceId.raw {
                throw PayNL.Failure.invalidResponse
            }
            if let reference, let requested = input.reference, reference != requested.raw {
                throw PayNL.Failure.invalidResponse
            }
            if let amount {
                guard amount.value == input.amount.value,
                      amount.currency == input.amount.currency
                else { throw PayNL.Failure.invalidResponse }
            }
        }
    }
}
