import Foundation
import Primitives

public extension PayNL.TGU {
    struct ServiceID: CodableInvariant, Hashable, Sendable {
        public let raw: String

        public init(_ raw: String) throws(InvarianceFailure) {
            try Invariance([
                .length.min(12),
                .length.max(12),
                .predicate(
                    where: { $0.range(of: #"^SL-[0-9]{4}-[0-9]{4}$"#, options: .regularExpression) != nil },
                    on_failure: { _ in InvarianceViolation(ServiceIDFormatViolation()) }
                ),
            ]).require(raw)
            self.raw = raw
        }
    }
}

public extension PayNL.TGU.Order {
    struct Reference: CodableInvariant, Hashable, Sendable {
        public let raw: String

        public init(_ raw: String) throws(InvarianceFailure) {
            try Invariance([
                .text.nonblank,
                .length.max(128),
                .predicate(
                    where: { $0.range(of: #"^[A-Za-z0-9-]+$"#, options: .regularExpression) != nil },
                    on_failure: { _ in InvarianceViolation(OrderReferenceFormatViolation()) }
                ),
            ]).require(raw)
            self.raw = raw
        }
    }

    struct Input: Encodable, Sendable {
        public struct Amount: Encodable, Sendable {
            public let value: Int64
            public let currency: PayNL.Currency

            public init(value: Int64, currency: PayNL.Currency) throws(InvarianceFailure) {
                try Invariance([.range.min(1)]).require(value)
                self.value = value
                self.currency = currency
            }
        }

        public struct PaymentMethod: Encodable, Sendable {
            public let id: Int
            public let input: JSONValue?

            public init(id: Int, input: JSONValue? = nil) throws(InvarianceFailure) {
                try Invariance([.range.min(1)]).require(id)
                self.id = id
                self.input = input
            }
        }

        public enum PointOfInteraction: String, Encodable, Sendable {
            case on_the_move = "ON_THE_MOVE"
            case ecommerce = "ECOMMERCE"
            case in_person = "IN_PERSON"
            case invoice = "INVOICE"
            case debt_collection = "DEBT_COLLECTION"
            case funding = "FUNDING"
            case payment_request = "PAYMENT_REQUEST"
            case recurring = "RECURRING"
            case unattended = "UNATTENDED"
            case moto = "MOTO"
            case payout = "PAYOUT"
        }

        public let serviceId: PayNL.TGU.ServiceID
        public let amount: Amount
        public let description: String?
        public let reference: Reference?
        public let expire: String?
        public let returnUrl: URL?
        public let exchangeUrl: URL?
        public let paymentMethod: PaymentMethod?
        public let locale: String?
        public let pointOfInteraction: PointOfInteraction?
        public let optimize: Optimize?
        public let customer: Customer?
        public let order: Order?
        public let splitPayments: [SplitPayment]?
        public let stats: Stats?
        public let transferData: JSONValue?

        public init(
            serviceId: PayNL.TGU.ServiceID,
            amount: Amount,
            description: String? = nil,
            reference: Reference? = nil,
            expire: Date? = nil,
            returnUrl: URL? = nil,
            exchangeUrl: URL? = nil,
            paymentMethod: PaymentMethod? = nil,
            locale: String? = nil,
            pointOfInteraction: PointOfInteraction? = nil,
            optimize: Optimize? = nil,
            customer: Customer? = nil,
            order: Order? = nil,
            splitPayments: [SplitPayment]? = nil,
            stats: Stats? = nil,
            transferData: JSONValue? = nil
        ) {
            self.serviceId = serviceId
            self.amount = amount
            self.description = description
            self.reference = reference
            self.expire = expire.map { ISO8601DateFormatter().string(from: $0) }
            self.returnUrl = returnUrl
            self.exchangeUrl = exchangeUrl
            self.paymentMethod = paymentMethod
            self.locale = locale
            self.pointOfInteraction = pointOfInteraction
            self.optimize = optimize
            self.customer = customer
            self.order = order
            self.splitPayments = splitPayments
            self.stats = stats
            self.transferData = transferData
        }
    }
}

private struct ServiceIDFormatViolation: InvarianceReason {
    let code: InvarianceCode = .custom("paynl.tgu.invalid_service_id")
    let message = "Expected SL-1234-5678 service identifier."
}

private struct OrderReferenceFormatViolation: InvarianceReason {
    let code: InvarianceCode = .custom("paynl.tgu.invalid_order_reference")
    let message = "Order reference must contain only ASCII letters, digits or hyphens."
}
