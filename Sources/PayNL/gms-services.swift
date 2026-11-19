import Foundation

public extension PayNL.GMS.Client {
    nonisolated var services: PayNL.GMS.Services { .init(client: self) }
}

public extension PayNL.GMS {
    struct Services: Sendable {
        let client: Client

        init(client: Client) {
            self.client = client
        }

        /// GET /v2/services/list. A compact, unpaginated list.
        public func list(
            merchant: String? = nil,
            status: String? = nil,
            excludingStatus: String? = nil
        ) async throws -> Service.Listing {
            var query = try merchantQuery(merchant)
            if let status = try filterValue(status) {
                query.append(.init(name: "status[eq]", value: status))
            }
            if let status = try filterValue(excludingStatus) {
                query.append(.init(name: "status[neq]", value: status))
            }
            let result: Service.Listing = try await client.execute(
                path: "/v2/services/list", query: query, as: Service.Listing.self
            )
            guard result.total.map({ $0 >= 0 }) ?? true,
                  Set(result.services.map(\.code)).count == result.services.count
            else { throw PayNL.Failure.invalidResponse }
            return result
        }

        /// GET /v2/services. Full records with paging metadata.
        public func browse(
            page: PayNL.PageNumber = .first,
            limit: PayNL.PageLimit = .standard,
            merchant: String? = nil
        ) async throws -> Page<Service> {
            var query: [URLQueryItem] = [
                .init(name: "page", value: String(page.raw)),
                .init(name: "limit", value: String(limit.raw)),
            ]
            query += try merchantQuery(merchant)
            let envelope: BrowseEnvelope = try await client.execute(
                path: "/v2/services", query: query, as: BrowseEnvelope.self
            )
            guard Set(envelope.services.map(\.code)).count == envelope.services.count else {
                throw PayNL.Failure.invalidResponse
            }
            return try Page(
                total: envelope.total, count: envelope.count,
                pages: envelope.pages, items: envelope.services
            )
        }

        /// GET /v2/services/{serviceId}.
        public func get(_ id: Service.ID) async throws -> Service {
            let result: Service = try await client.execute(
                path: "/v2/services/\(PayNL.encoded(id.raw))", as: Service.self
            )
            guard result.code == id else { throw PayNL.Failure.invalidResponse }
            return result
        }

        /// GET /v2/services/{serviceId}/info.
        public func info(_ id: Service.ID) async throws -> Service.Info {
            let result: Service.Info = try await client.execute(
                path: "/v2/services/\(PayNL.encoded(id.raw))/info", as: Service.Info.self
            )
            guard result.code == id else { throw PayNL.Failure.invalidResponse }
            return result
        }

        /// GET /v2/services/{serviceId}/paymentmethods, including boarding status.
        public func paymentMethods(
            for id: Service.ID,
            merchant: String? = nil
        ) async throws -> Service.PaymentMethods {
            let result: Service.PaymentMethods = try await client.execute(
                path: "/v2/services/\(PayNL.encoded(id.raw))/paymentmethods",
                query: try merchantQuery(merchant), as: Service.PaymentMethods.self
            )
            let ids = result.paymentMethods.map(\.id)
            guard ids.allSatisfy({ $0 > 0 }), Set(ids).count == ids.count else {
                throw PayNL.Failure.invalidResponse
            }
            return result
        }

        private func merchantQuery(_ merchant: String?) throws -> [URLQueryItem] {
            guard let merchant = try filterValue(merchant) else { return [] }
            return [.init(name: "merchant[eq]", value: merchant)]
        }

        private func filterValue(_ value: String?) throws -> String? {
            guard let value else { return nil }
            guard !value.isEmpty,
                  value == value.trimmingCharacters(in: .whitespacesAndNewlines),
                  !value.contains(where: \.isNewline)
            else { throw PayNL.Failure.invalidResponse }
            return value
        }

        private struct BrowseEnvelope: Decodable, Sendable {
            let total: Int?
            let count: Int
            let pages: Int
            let services: [Service]
        }
    }
}
