import Foundation
import PayNL
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

actor FixtureServer {
    private(set) var requests: [URLRequest] = []

    func send(_ request: URLRequest) throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        guard let url = request.url else { throw PayNL.Failure.invalidResponse }
        let payload: String
        switch url.path {
        case "/v2/transactions":
            payload = """
                {"total":1,"count":1,"pages":1,"transactions":[{"id":"EX-1234-5678-9012","description":"Invoice","amount":{"value":1250,"currency":"EUR"},"status":{"action":"PAID","phase":"APPROVED"}}]}
                """
        case "/v2/transactions/EX-1234-5678-9012":
            payload = """
                {"id":"EX-1234-5678-9012","description":"Invoice","amount":{"value":1250,"currency":"EUR"},"status":{"code":100,"action":"PAID"}}
                """
        case "/v2/orders/order-id-123/status":
            payload = """
                {"id":"order-id-123","orderId":"order-987","status":{"code":20,"name":"pending","action":"PENDING"},"amount":{"value":1250,"currency":"EUR"}}
                """
        default:
            throw PayNL.Failure.invalidResponse
        }
        guard let response = HTTPURLResponse(
            url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: [:]
        ) else { throw PayNL.Failure.invalidTransportResponse }
        return (Data(payload.utf8), response)
    }

    func check() throws {
        guard requests.count == 3 else { throw PayNL.Failure.invalidResponse }
        guard requests[0].url?.absoluteString == "https://rest.pay.nl/v2/transactions?page=2&limit=25" else { throw PayNL.Failure.invalidResponse }
        guard requests[0].value(forHTTPHeaderField: "Authorization")?.hasPrefix("Basic ") == true else { throw PayNL.Failure.invalidResponse }
        guard requests[1].url?.host == "rest.pay.nl" else { throw PayNL.Failure.invalidResponse }
        guard requests[2].url?.host == "connect.pay.nl" else { throw PayNL.Failure.invalidResponse }
        guard requests[2].value(forHTTPHeaderField: "Authorization") == "Bearer fixture-token" else { throw PayNL.Failure.invalidResponse }
    }
}

func run() async throws {
    let server = FixtureServer()
    let transport = PayNL.Transport { request in try await server.send(request) }
    let user = try PayNL.Secret("user")
    let password = try PayNL.Secret("password")
    let client = PayNL.Idefix.Client(
        credentials: .init(username: user, password: password), transport: transport
    )
    let list = try await client.transactions.list(
        page: PayNL.PageNumber(2), limit: PayNL.PageLimit(25)
    )
    guard list.transactions.count == 1, list.transactions[0].amount?.value == 1250 else {
        throw PayNL.Failure.invalidResponse
    }
    let id = try PayNL.Idefix.Transaction.ID("EX-1234-5678-9012")
    let item = try await client.transactions.get(id)
    guard item.id == id, item.status?.action == "PAID" else { throw PayNL.Failure.invalidResponse }
    guard item.idRepresentation == .ex_code else { throw PayNL.Failure.invalidResponse }
    // A cancelled/expired detail may literally return its order ID as `id`.
    // Decode it unchanged; never synthesize the browse EX code from the response.
    let expired = try JSONDecoder().decode(
        PayNL.Idefix.Transaction.self,
        from: Data(#"{"id":"ORDER-EXPIRED","orderId":"ORDER-EXPIRED","status":{"code":-80,"action":"CANCEL","phase":"EXPIRED"}}"#.utf8)
    )
    guard expired.idRepresentation == .order_id,
          expired.id.raw == expired.orderId,
          expired.id.raw != id.raw else { throw PayNL.Failure.invalidResponse }
    let other = try JSONDecoder().decode(
        PayNL.Idefix.Transaction.self,
        from: Data(#"{"id":"UNRECOGNIZED","orderId":"ORDER-OTHER"}"#.utf8)
    )
    guard other.idRepresentation == .other else { throw PayNL.Failure.invalidResponse }
    let orders = PayNL.TGU.Client(credentials: .bearer(try PayNL.Secret("fixture-token")), transport: transport)
    let order = try await orders.orders.status(PayNL.TGU.Order.ID("order-id-123"))
    guard order.id.raw == "order-id-123", order.status?.code == 20 else { throw PayNL.Failure.invalidResponse }
    try await server.check()
    guard (try? PayNL.PageLimit(101)) == nil, (try? PayNL.Idefix.Transaction.ID("")) == nil else {
        throw PayNL.Failure.invalidResponse
    }

    let unauthorized = PayNL.Transport { request in
        guard let url = request.url,
              let response = HTTPURLResponse(url: url, statusCode: 401, httpVersion: nil, headerFields: [:])
        else { throw PayNL.Failure.invalidResponse }
        return (Data("{}".utf8), response)
    }
    let rejectedClient = PayNL.Idefix.Client(
        credentials: .init(username: user, password: password), transport: unauthorized
    )
    do {
        _ = try await rejectedClient.transactions.get(id)
        throw PayNL.Failure.invalidResponse
    } catch PayNL.Failure.http(status: 401) {
        // A rejected request must not be represented as a successful result.
    }
    guard (try? JSONDecoder().decode(PayNL.Idefix.Transaction.self, from: Data(#"{"id":"","amount":{"value":1}}"#.utf8))) == nil else {
        throw PayNL.Failure.invalidResponse
    }
    try await runHardeningTests()
    try await runExpansionTests()
    try await runTGUOrderCreationTests()
    try await runTGUv2ContractTests()
    try await runGMSServicesTests()
    try runWireKeyConvergenceTests()
    print("PayNL Idefix, GMS services, and TGU order fixtures: PASS")
}

try await run()
