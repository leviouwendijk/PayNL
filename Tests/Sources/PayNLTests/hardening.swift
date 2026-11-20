import PayNL
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

func runHardeningTests() async throws {
    let decoder = JSONDecoder()
    guard (try? PayNL.Currency("EUR"))?.raw == "EUR",
          (try? PayNL.Currency("EU")) == nil,
          (try? PayNL.Currency("€UR")) == nil,
          (try? PayNL.Currency("eur")) == nil else {
        throw PayNL.Failure.invalidResponse
    }
    let negativeTotal = #"{"total":-1,"count":0,"transactions":[]}"#
    let negativePages = #"{"total":0,"count":0,"pages":-2,"transactions":[]}"#
    for payload in [negativeTotal, negativePages] {
        guard (try? decoder.decode(PayNL.Idefix.Page.self, from: Data(payload.utf8))) == nil else {
            throw PayNL.Failure.invalidResponse
        }
    }
    let badCurrency = #"{"value":1250,"currency":"eUR"}"#
    guard (try? decoder.decode(PayNL.Amount.self, from: Data(badCurrency.utf8))) == nil else {
        throw PayNL.Failure.invalidResponse
    }

    let credentials = PayNL.TGU.Credentials.bearer(try PayNL.Secret("fixture-token"))
    let requestedID = try PayNL.TGU.Order.ID("order-1")
    for payload in [
        #"{"id":"order-1"}"#,
        #"{"id":"order-1","status":{}}"#,
        #"{"id":"order-2","status":{"code":20}}"#,
    ] {
        let transport = PayNL.Transport { request in
            guard let url = request.url,
                  let response = HTTPURLResponse(
                    url: url, statusCode: 200, httpVersion: nil, headerFields: [:]
                  ) else { throw PayNL.Failure.invalidTransportResponse }
            return (Data(payload.utf8), response)
        }
        let client = PayNL.TGU.Client(credentials: credentials, transport: transport)
        var rejected = false
        do {
            _ = try await client.orders.status(requestedID)
        } catch PayNL.Failure.invalidResponse {
            rejected = true
        }
        guard rejected else { throw PayNL.Failure.invalidResponse }
    }
}
