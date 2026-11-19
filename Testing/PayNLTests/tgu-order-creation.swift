import Foundation
import PayNL
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

func runTGUOrderCreationTests() async throws {
    let input = PayNL.TGU.Order.Input(
        serviceId: try .init("SL-1234-5678"),
        amount: try .init(value: 127_000, currency: PayNL.Currency("EUR")),
        description: "Invoice 2026-001",
        reference: try .init("INV2026-001"),
        paymentMethod: try .init(id: 961)
    )

    let transport = PayNL.Transport { request in
        guard let url = request.url,
              url.absoluteString == "https://connect.pay.nl/v2/orders",
              request.httpMethod == "POST",
              request.value(forHTTPHeaderField: "Pay-Environment") == "test",
              request.value(forHTTPHeaderField: "Content-Type") == "application/json",
              request.value(forHTTPHeaderField: "Authorization")?.hasPrefix("Basic ") == true,
              let body = request.httpBody,
              let json = try JSONSerialization.jsonObject(with: body) as? [String: Any],
              json["serviceId"] as? String == "SL-1234-5678",
              json["reference"] as? String == "INV2026-001",
              json["description"] as? String == "Invoice 2026-001",
              let amount = json["amount"] as? [String: Any],
              amount["value"] as? Int == 127_000,
              amount["currency"] as? String == "EUR",
              let paymentMethod = json["paymentMethod"] as? [String: Any],
              paymentMethod["id"] as? Int == 961,
              json["integration"] == nil,
              let response = HTTPURLResponse(url: url, statusCode: 201, httpVersion: nil, headerFields: [:])
        else { throw PayNL.Failure.invalidResponse }
        let payload = #"{"id":"e0e90000-1111-2222-3333-444444444444","status":{"code":20,"action":"PENDING"},"links":{"redirect":"https://checkout.pay.nl/to/payment/test-order","status":"https://connect.pay.nl/v2/orders/e0e90000-1111-2222-3333-444444444444/status"},"amount":{"value":127000,"currency":"EUR"}}"#
        return (Data(payload.utf8), response)
    }

    let client = PayNL.TGU.Client(
        credentials: .basic(
            username: try PayNL.Secret("AT-1234-5678"),
            password: try PayNL.Secret("fixture-token")
        ),
        environment: .test,
        transport: transport
    )
    let order = try await client.orders.create(input)
    guard order.id.raw == "e0e90000-1111-2222-3333-444444444444",
          order.status?.action == "PENDING",
          order.links?.redirect?.absoluteString == "https://checkout.pay.nl/to/payment/test-order"
    else { throw PayNL.Failure.invalidResponse }

    guard (try? PayNL.TGU.ServiceID("SL-NOT-VALID")) == nil,
          (try? PayNL.TGU.Order.Reference("INV_001")) == nil,
          (try? PayNL.TGU.Order.Input.Amount(value: 0, currency: PayNL.Currency("EUR"))) == nil
    else { throw PayNL.Failure.invalidResponse }

    let rejectedTransport = PayNL.Transport { request in
        guard let url = request.url,
              let response = HTTPURLResponse(url: url, statusCode: 422, httpVersion: nil, headerFields: [:])
        else { throw PayNL.Failure.invalidTransportResponse }
        return (Data(#"{"code":"INVALID_AMOUNT"}"#.utf8), response)
    }
    let rejectedClient = PayNL.TGU.Client(
        credentials: .bearer(try PayNL.Secret("fixture-token")),
        environment: .test,
        transport: rejectedTransport
    )
    do {
        _ = try await rejectedClient.orders.create(input)
        throw PayNL.Failure.invalidResponse
    } catch PayNL.Failure.http(status: 422) {
    }
}
