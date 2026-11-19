import Foundation
import Primitives

public extension PayNL.GMS {
    /// Read-only GMS sales location. The provider's `secret` field is intentionally not exposed.
    struct Service: Decodable, Sendable {
        public typealias ID = PayNL.TGU.ServiceID

        public struct Descriptor: Decodable, Sendable {
            public let code: String
            public let name: String?
        }

        public struct Summary: Decodable, Sendable {
            public let code: ID
            public let name: String?
            public let status: String?
            public let translations: JSONValue?
        }

        public struct Listing: Decodable, Sendable {
            public let total: Int?
            public let services: [Summary]
        }

        public struct Overridable<Value: Decodable & Sendable>: Decodable, Sendable {
            public let defaultValue: Value?
            public let value: Value?

            public var effectiveValue: Value? { value ?? defaultValue }
        }

        public struct Address: Decodable, Sendable {
            public let code: String?
            public let streetName: String?
            public let streetNumber: String?
            public let zipCode: String?
            public let city: String?
            public let countryCode: String?
            public let regionCode: String?
        }

        public struct ConfiguredPaymentMethod: Decodable, Sendable {
            public let id: Int
            public let settings: JSONValue?
        }

        public struct Info: Decodable, Sendable {
            public let code: ID
            public let merchant: PayNL.GMS.Merchant?
            public let name: String?
            public let description: String?
            public let status: String?
            public let testMode: Bool?
            public let category: Descriptor?
            public let tradeName: Descriptor?
            public let integrationVersion: Descriptor?
            public let turnoverGroup: Descriptor?
            public let mcc: Int?
            public let translations: JSONValue?
            public let layout: JSONValue?
            public let contactPhone: Overridable<String>?
            public let contactEmail: Overridable<String>?
            public let legalRegistrationNumber: Overridable<String>?
            public let address: Overridable<Address>?
            public let publication: JSONValue?
            public let settings: JSONValue?
            public let paymentMethods: [ConfiguredPaymentMethod]?
            public let createdAt: String?
            public let modifiedAt: String?
        }

        public struct PaymentMethod: Decodable, Sendable {
            public struct Boarding: Decodable, Sendable {
                public let code: String?
                public let status: String?
                public let completedAt: String?
            }

            public let id: Int
            public let name: String?
            public let active: Bool?
            public let boarding: Boarding?
            public let settings: JSONValue?
        }

        public struct PaymentMethods: Decodable, Sendable {
            public let paymentMethods: [PaymentMethod]
        }

        public let code: ID
        public let merchant: PayNL.GMS.Merchant?
        public let name: String?
        public let description: String?
        public let status: String?
        public let testMode: Bool?
        public let category: Descriptor?
        public let tradeName: Descriptor?
        public let integrationVersion: Descriptor?
        public let turnoverGroup: Descriptor?
        public let mcc: Int?
        public let translations: JSONValue?
        public let createdAt: String?
        public let modifiedAt: String?
    }
}
