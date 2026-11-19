import Foundation
import Primitives

public extension PayNL {
    struct Currency: CodableInvariant, Sendable, Hashable {
        public let raw: String

        public init(_ raw: String) throws(InvarianceFailure) {
            try Invariance([
                .length.min(3),
                .length.max(3),
                .predicate(
                    where: { value in
                        value.unicodeScalars.allSatisfy { $0.value >= 65 && $0.value <= 90 }
                    },
                    on_failure: { _ in InvarianceViolation(CurrencyFormatViolation()) }
                ),
            ]).require(raw)
            self.raw = raw
        }
    }
}

private struct CurrencyFormatViolation: InvarianceReason {
    let code: InvarianceCode = .custom("currency.invalid_format")
    let message = "Currency must have exactly three uppercase ASCII letters."
}
