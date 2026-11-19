import Foundation
import Primitives

public extension PayNL.TGU.Order.Input {
    struct Company: Encodable, Sendable {
        public let name: String?
        public let cocNumber: String?
        public let vatNumber: String?
        public let country: String?

        public init(name: String? = nil, cocNumber: String? = nil, vatNumber: String? = nil, country: String? = nil) {
            self.name = name
            self.cocNumber = cocNumber
            self.vatNumber = vatNumber
            self.country = country
        }
    }

    struct Customer: Encodable, Sendable {
        public let email: String?
        public let firstName: String?
        public let lastName: String?
        public let birthDate: String?
        public let gender: String?
        public let phone: String?
        public let locale: String?
        public let ipAddress: String?
        public let trust: Int?
        public let reference: String?
        public let gaClientId: String?
        public let company: Company?

        public init(
            email: String? = nil, firstName: String? = nil, lastName: String? = nil,
            birthDate: String? = nil, gender: String? = nil, phone: String? = nil,
            locale: String? = nil, ipAddress: String? = nil, trust: Int? = nil,
            reference: String? = nil, gaClientId: String? = nil, company: Company? = nil
        ) {
            self.email = email
            self.firstName = firstName
            self.lastName = lastName
            self.birthDate = birthDate
            self.gender = gender
            self.phone = phone
            self.locale = locale
            self.ipAddress = ipAddress
            self.trust = trust
            self.reference = reference
            self.gaClientId = gaClientId
            self.company = company
        }
    }

    struct Address: Encodable, Sendable {
        public let firstName: String?
        public let lastName: String?
        public let street: String
        public let streetNumber: String
        public let streetNumberExtension: String?
        public let zipCode: String
        public let city: String
        public let country: String
        public let region: String?

        public init(
            street: String, streetNumber: String, zipCode: String, city: String, country: String,
            firstName: String? = nil, lastName: String? = nil,
            streetNumberExtension: String? = nil, region: String? = nil
        ) {
            self.firstName = firstName
            self.lastName = lastName
            self.street = street
            self.streetNumber = streetNumber
            self.streetNumberExtension = streetNumberExtension
            self.zipCode = zipCode
            self.city = city
            self.country = country
            self.region = region
        }
    }

    struct Product: Encodable, Sendable {
        public let id: String?
        public let description: String?
        public let type: String?
        public let price: Amount?
        public let quantity: Decimal?
        public let vatPercentage: Decimal?
        public let productUrl: URL?
        public let imageUrl: URL?

        public init(
            id: String? = nil, description: String? = nil, type: String? = nil,
            price: Amount? = nil, quantity: Decimal? = nil,
            vatPercentage: Decimal? = nil, productUrl: URL? = nil, imageUrl: URL? = nil
        ) {
            self.id = id
            self.description = description
            self.type = type
            self.price = price
            self.quantity = quantity
            self.vatPercentage = vatPercentage
            self.productUrl = productUrl
            self.imageUrl = imageUrl
        }
    }

    struct Order: Encodable, Sendable {
        public let countryCode: String?
        public let deliveryDate: String?
        public let invoiceDate: String?
        public let statusUrl: URL?
        public let deliveryAddress: Address?
        public let invoiceAddress: Address?
        public let products: [Product]?

        public init(
            countryCode: String? = nil, deliveryDate: String? = nil,
            invoiceDate: String? = nil, statusUrl: URL? = nil,
            deliveryAddress: Address? = nil, invoiceAddress: Address? = nil,
            products: [Product]? = nil
        ) {
            self.countryCode = countryCode
            self.deliveryDate = deliveryDate
            self.invoiceDate = invoiceDate
            self.statusUrl = statusUrl
            self.deliveryAddress = deliveryAddress
            self.invoiceAddress = invoiceAddress
            self.products = products
        }
    }

    struct SplitPayment: Encodable, Sendable {
        public enum Fee: String, Encodable, Sendable {
            case receiver
            case sender
        }

        public let serviceId: PayNL.TGU.ServiceID
        public let fee: Fee
        public let amount: Amount

        public init(serviceId: PayNL.TGU.ServiceID, fee: Fee = .receiver, amount: Amount) {
            self.serviceId = serviceId
            self.fee = fee
            self.amount = amount
        }
    }

    struct Stats: Encodable, Sendable {
        public let tool: String?
        public let info: String?
        public let object: String?
        public let extra1: String?
        public let extra2: String?
        public let extra3: String?
        public let domainId: String?
        public let promotorId: Int?

        public init(
            tool: String? = nil, info: String? = nil, object: String? = nil,
            extra1: String? = nil, extra2: String? = nil, extra3: String? = nil,
            domainId: String? = nil, promotorId: Int? = nil
        ) {
            self.tool = tool
            self.info = info
            self.object = object
            self.extra1 = extra1
            self.extra2 = extra2
            self.extra3 = extra3
            self.domainId = domainId
            self.promotorId = promotorId
        }
    }

    struct Optimize: Encodable, Sendable {
        public struct CollectorAccount: Encodable, Sendable {
            public struct IBAN: Encodable, Sendable {
                public let iban: String
                public let bic: String
                public let owner: String

                public init(iban: String, bic: String, owner: String) {
                    self.iban = iban
                    self.bic = bic
                    self.owner = owner
                }
            }

            public let method: String
            public let iban: IBAN?

            public init(iban: IBAN) {
                self.method = "iban"
                self.iban = iban
            }
        }

        public struct CollectorCompany: Encodable, Sendable {
            public let id: String
            public let name: String
            public let countryCode: String

            public init(id: String, name: String, countryCode: String) {
                self.id = id
                self.name = name
                self.countryCode = countryCode
            }
        }

        public enum Flow: String, Encodable, Sendable {
            case fast_checkout = "fastCheckout"
        }

        public let flow: Flow?
        public let shippingAddress: Bool?
        public let billingAddress: Bool?
        public let contactDetails: Bool?
        public let mcc: String?
        public let collectorAccount: CollectorAccount?
        public let collectorCompany: CollectorCompany?
        public let klarnaMerchantData: [String]?

        public init(
            flow: Flow? = nil, shippingAddress: Bool? = nil,
            billingAddress: Bool? = nil, contactDetails: Bool? = nil,
            mcc: String? = nil, collectorAccount: CollectorAccount? = nil,
            collectorCompany: CollectorCompany? = nil, klarnaMerchantData: [String]? = nil
        ) {
            self.flow = flow
            self.shippingAddress = shippingAddress
            self.billingAddress = billingAddress
            self.contactDetails = contactDetails
            self.mcc = mcc
            self.collectorAccount = collectorAccount
            self.collectorCompany = collectorCompany
            self.klarnaMerchantData = klarnaMerchantData
        }
    }
}
