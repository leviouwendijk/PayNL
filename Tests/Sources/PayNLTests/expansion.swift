import PayNL
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

actor PayNLReadServer {
    private(set) var requests: [URLRequest] = []

    func send(_ request: URLRequest) throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        guard let url = request.url else { throw PayNL.Failure.invalidResponse }
        let payload: String
        switch (url.host, url.path) {
        case ("rest.pay.nl", "/v2/transactions"):
            payload = #"{"total":1,"count":1,"pages":1,"transactions":[{"id":"EX-1234-5678-9012","amount":{"value":1250,"currency":"EUR"},"amountRefunded":{"value":250,"currency":"EUR"},"createdAt":"2024-05-26T01:52:59+02:00"}]}"#
        case ("rest.pay.nl", "/v2/transactions/find"):
            payload = #"{"total":1,"count":1,"transactions":[{"id":"EX-1234-5678-9012","reference":"INV-001"}]}"#
        case ("gms.pay.nl", "/v2/clearings"):
            payload = #"{"total":1,"count":1,"pages":1,"clearings":[{"id":"CLEARING-20212977767","status":"PAID","settlementCode":"SK6Y-7PBP","period":"2023-01","costs":{"value":10,"currency":"EUR"}}]}"#
        case ("gms.pay.nl", "/v2/clearings/CLEARING-20212977767"):
            payload = #"{"id":"CLEARING-20212977767","settlementCode":"SK6Y-7PBP","status":"PAID","costs":{"value":10,"currency":"EUR"}}"#
        case ("gms.pay.nl", "/v2/clearings/CLEARING-20212977767/lines"):
            payload = #"{"total":1,"count":1,"pages":1,"clearingLines":[{"code":"FT-1234-4321-1234","state":"SETTLED","volume":{"value":100,"currency":"EUR"},"transactions":3}]}"#
        case ("gms.pay.nl", "/v2/clearings/settlements"):
            payload = #"{"total":1,"count":1,"pages":1,"settlements":[{"code":"SK6Y-7PBP","settlementDate":"2024-06-04","amount":{"value":100,"currency":"EUR"},"baseAccountIban":"NL35RABO0117713678","clearings":[{"clearingId":"CLEARING-20212977767","clearingLines":[{"code":"FT-1234-4321-1234","state":"PROCESSED","amount":{"value":100,"currency":"EUR"},"transactions":3}]}]}]}"#
        default:
            throw PayNL.Failure.invalidResponse
        }
        guard let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: [:]) else {
            throw PayNL.Failure.invalidTransportResponse
        }
        return (Data(payload.utf8), response)
    }

    func check() throws {
        guard requests.count == 6 else { throw PayNL.Failure.invalidResponse }
        guard requests[0].url?.query?.contains("amount%5Beq%5D=1250") == true,
              requests[0].url?.query?.contains("id%5Beq%5D=EX-1234-5678-9012") == true
        else { throw PayNL.Failure.invalidResponse }
        guard requests[1].url?.query?.contains("needle%5Beq%5D=INV-001") == true else {
            throw PayNL.Failure.invalidResponse
        }
        guard requests[2].value(forHTTPHeaderField: "Authorization") == "Bearer fixture-gms-token" else {
            throw PayNL.Failure.invalidResponse
        }
        guard requests[5].url?.host == "gms.pay.nl",
              requests[5].url?.query == "page=1&limit=10" else {
            throw PayNL.Failure.invalidResponse
        }
    }
}

func runExpansionTests() async throws {
    let server = PayNLReadServer()
    let transport = PayNL.Transport { request in try await server.send(request) }
    let transactionID = try PayNL.Idefix.Transaction.ID("EX-1234-5678-9012")
    let idefix = PayNL.Idefix.Client(
        credentials: .init(username: try PayNL.Secret("user"), password: try PayNL.Secret("password")),
        transport: transport
    )
    let filtered = try await idefix.transactions.list(
        filter: .init(id: transactionID, amount: 1250)
    )
    guard filtered.transactions.count == 1,
          filtered.transactions[0].amountRefunded?.value == 250,
          filtered.transactions[0].createdAt == "2024-05-26T01:52:59+02:00"
    else { throw PayNL.Failure.invalidResponse }

    let matched = try await idefix.transactions.find(.init("INV-001"))
    guard matched.transactions.count == 1, matched.transactions[0].id == transactionID else {
        throw PayNL.Failure.invalidResponse
    }

    let gms = PayNL.GMS.Client(
        credentials: .bearer(try PayNL.Secret("fixture-gms-token")),
        transport: transport
    )
    let id = try PayNL.GMS.Clearing.ID("CLEARING-20212977767")
    let clearings = try await gms.clearings.list()
    guard clearings.items.count == 1,
          clearings.items[0].id == id,
          clearings.items[0].costs?.value == 10
    else { throw PayNL.Failure.invalidResponse }
    let clearing = try await gms.clearings.get(id)
    guard clearing.id == id, clearing.status == "PAID" else { throw PayNL.Failure.invalidResponse }
    let lines = try await gms.clearings.lines(for: id)
    guard lines.items.count == 1, lines.items[0].volume?.value == 100 else {
        throw PayNL.Failure.invalidResponse
    }
    let settlements = try await gms.settlements.list()
    guard settlements.items.count == 1,
          settlements.items[0].code.raw == "SK6Y-7PBP",
          settlements.items[0].amount?.value == 100,
          settlements.items[0].clearings?.first?.clearingId == id
    else { throw PayNL.Failure.invalidResponse }
    try await server.check()
    guard (try? PayNL.GMS.SettlementLimit(11)) == nil,
          (try? PayNL.Idefix.SearchTerm(" ")) == nil
    else { throw PayNL.Failure.invalidResponse }

    for invalidEnvelope in [
        #"{"total":1,"count":1,"pages":1,"clearings":[]}"#,
        #"{"total":1,"count":1,"pages":1,"settlements":[{"code":"SK6Y-7PBP"}]}"#,
    ] {
        let badTransport = PayNL.Transport { request in
            guard let url = request.url,
                  let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: [:])
            else { throw PayNL.Failure.invalidTransportResponse }
            return (Data(invalidEnvelope.utf8), response)
        }
        let badClient = PayNL.GMS.Client(
            credentials: .bearer(try PayNL.Secret("token")), transport: badTransport
        )
        var rejected = false
        do {
            _ = try await badClient.clearings.list()
        } catch PayNL.Failure.invalidResponse {
            rejected = true
        } catch is DecodingError {
            rejected = true
        }
        guard rejected else { throw PayNL.Failure.invalidResponse }
    }

    let wrongIDTransport = PayNL.Transport { request in
        guard let url = request.url,
              let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: [:])
        else { throw PayNL.Failure.invalidTransportResponse }
        return (Data(#"{"id":"OTHER-CLEARING"}"#.utf8), response)
    }
    let wrongIDClient = PayNL.GMS.Client(credentials: .bearer(try PayNL.Secret("token")), transport: wrongIDTransport)
    var rejectedWrongID = false
    do {
        _ = try await wrongIDClient.clearings.get(id)
    } catch PayNL.Failure.invalidResponse {
        rejectedWrongID = true
    }
    guard rejectedWrongID else { throw PayNL.Failure.invalidResponse }

    // GMS Basic authentication must encode AT-code:API-token, not API-token:.
    let expectedAuthorization = "Basic \(Data("AT-1234-4321:fixture-api-token".utf8).base64EncodedString())"
    let basicServer = PayNL.Transport { request in
        guard request.value(forHTTPHeaderField: "Authorization") == expectedAuthorization,
              request.url?.host == "gms.pay.nl",
              let url = request.url,
              let response = HTTPURLResponse(url: url, statusCode: 401, httpVersion: nil, headerFields: [:])
        else { throw PayNL.Failure.invalidResponse }
        return (Data("{}".utf8), response)
    }
    let basicClient = PayNL.GMS.Client(
        credentials: .apiToken(
            at_code: try PayNL.Secret("AT-1234-4321"),
            api_token: try PayNL.Secret("fixture-api-token")
        ),
        transport: basicServer
    )
    var rejectedUnauthorized = false
    do {
        _ = try await basicClient.clearings.list()
    } catch PayNL.Failure.http(status: 401) {
        rejectedUnauthorized = true
    }
    guard rejectedUnauthorized else { throw PayNL.Failure.invalidResponse }
}
