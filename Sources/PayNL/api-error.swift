import Foundation

public extension PayNL {
    struct APIError: Error, Sendable, LocalizedError {
        public struct Violation: Decodable, Sendable {
            public let propertyPath: String?
            public let message: String?
            public let code: String?
        }

        private struct Problem: Decodable {
            let type: String?
            let title: String?
            let detail: String?
            let code: String?
            let instance: String?
            let traceId: String?
            let violations: [Violation]?
        }

        public let httpStatus: Int
        public let type: String?
        public let title: String?
        public let detail: String?
        public let code: String?
        public let instance: String?
        public let traceId: String?
        public let violations: [Violation]

        public var errorDescription: String? { detail ?? title ?? code }

        public static func decode(status: Int, from data: Data) -> Self? {
            guard let problem = try? JSONDecoder().decode(Problem.self, from: data) else {
                return nil
            }
            guard problem.type != nil || problem.title != nil || problem.detail != nil
                    || problem.violations?.isEmpty == false
                    || problem.code?.hasPrefix("PAY-") == true
            else { return nil }
            return Self(
                httpStatus: status,
                type: problem.type,
                title: problem.title,
                detail: problem.detail,
                code: problem.code,
                instance: problem.instance,
                traceId: problem.traceId,
                violations: problem.violations ?? []
            )
        }
    }
}
