import Foundation
import PayNL
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

func runTGUv2ContractTests() async throws {
    let amount = try PayNL.TGU.Order.Input.Amount(value: 127_000, currency: .init("EUR"))
    let input = PayNL.TGU.Order.Input(
        serviceId: try .init("SL-1234-5678"),
        amount: amount,
        reference: try .init("INVOICE-2026-01"),
        paymentMethod: try .init(id: 10, input: .object(["issuer": .string("fixture")])),
        locale: "nl_NL",
        pointOfInteraction: .invoice,
        optimize: .init(flow: .fast_checkout, shippingAddress: false),
        customer: .init(email: "client@example.test", firstName: "Example", company: .init(name: "Example BV")),
        order: .init(
            countryCode: "NL",
            invoiceAddress: .init(street: "Straat", streetNumber: "1", zipCode: "1000AA", city: "Amsterdam", country: "NL"),
            products: [
                .init(description: "Training", type: "ARTICLE", price: amount,
                      quantity: Decimal(string: "1.5"), vatPercentage: Decimal(string: "21"))
            ]
        ),
        splitPayments: [
            .init(serviceId: try .init("SL-8765-4321"), fee: .sender,
                  amount: try .init(value: 12_000, currency: .init("EUR")))
        ],
        stats: .init(tool: "PayNL-SDK", extra1: "order-test"),
        transferData: .object(["merchant": .string("test")])
    )

    let object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(input)) as? [String: Any]
    guard let object,
          object["locale"] as? String == "nl_NL",
          object["pointOfInteraction"] as? String == "INVOICE",
          object["integration"] == nil,
          object["notification"] == nil,
          let customer = object["customer"] as? [String: Any],
          customer["email"] as? String == "client@example.test",
          let company = customer["company"] as? [String: Any],
          company["name"] as? String == "Example BV",
          let order = object["order"] as? [String: Any],
          let products = order["products"] as? [[String: Any]],
          products.count == 1,
          (products[0]["quantity"] as? NSNumber)?.decimalValue == Decimal(string: "1.5"),
          let method = object["paymentMethod"] as? [String: Any],
          let methodInput = method["input"] as? [String: Any],
          methodInput["issuer"] as? String == "fixture",
          let splits = object["splitPayments"] as? [[String: Any]],
          splits.first?["fee"] as? String == "sender"
    else { throw PayNL.Failure.invalidResponse }

    let fullResponse = """
        {"id":"order-123","serviceId":"SL-1234-5678","reference":"INVOICE-2026-01",
         "amount":{"value":127000,"currency":"EUR"},"status":{"code":20,"action":"PENDING"},
         "authorizedAmount":{"value":0,"currency":"EUR"},"payments":[],
         "integration":{"pointOfInteraction":"INVOICE","test":true},
         "splitPayments":[{"serviceId":"SL-8765-4321","fee":"sender","amount":{"value":12000,"currency":"EUR"}}],
         "links":{"redirect":"https://checkout.pay.nl/to/payment/fixture","abort":null,
                  "capture":"https://connect.pay.nl/v2/orders/order-123/capture"}}
        """
    let decoded = try JSONDecoder().decode(PayNL.TGU.Order.self, from: Data(fullResponse.utf8))
    try decoded.validateForCreate(input)
    guard try decoded.requireRedirectURL().scheme == "https",
          decoded.links?["capture"] != nil,
          decoded.splitPayments?.first?.amount?.value == 12_000,
          decoded.integration?.test == true,
          decoded.payments?.isEmpty == true
    else { throw PayNL.Failure.invalidResponse }

    let missingLink = try JSONDecoder().decode(
        PayNL.TGU.Order.self,
        from: Data(#"{"id":"order-123","status":{"action":"PENDING"},"links":{}}"#.utf8)
    )
    do {
        _ = try missingLink.requireRedirectURL()
        throw PayNL.Failure.invalidResponse
    } catch PayNL.TGU.Order.CheckoutFailure.missingRedirect {}

    let insecureLink = try JSONDecoder().decode(
        PayNL.TGU.Order.self,
        from: Data(#"{"id":"order-123","status":{"action":"PENDING"},"links":{"redirect":"http://checkout.pay.nl/pay"}}"#.utf8)
    )
    do {
        _ = try insecureLink.requireRedirectURL()
        throw PayNL.Failure.invalidResponse
    } catch PayNL.TGU.Order.CheckoutFailure.invalidRedirect {}

    for invalid in [
        #"{"id":"order-123"}"#,
        #"{"id":"order-123","status":{"action":"PENDING"},"serviceId":"SL-0000-0000"}"#,
        #"{"id":"order-123","status":{"action":"PENDING"},"amount":{"value":1,"currency":"EUR"}}"#,
        #"{"id":"order-123","status":{"action":"PENDING"},"reference":"OTHER"}"#,
    ] {
        let decoded = try JSONDecoder().decode(PayNL.TGU.Order.self, from: Data(invalid.utf8))
        do {
            try decoded.validateForCreate(input)
            throw PayNL.Failure.invalidTransportResponse
        } catch PayNL.Failure.invalidResponse {}
    }

    let problemBody = """
        {"type":"https://example.test/problem","title":"Validation error","detail":"amount: Invalid",
         "code":"PAY-1422","traceId":"trace-fixture",
         "violations":[{"propertyPath":"amount.value","message":"Too low","code":"PAY-2002"}]}
        """
    let problemTransport = PayNL.Transport { request in
        guard let url = request.url,
              let response = HTTPURLResponse(url: url, statusCode: 422, httpVersion: nil, headerFields: [:])
        else { throw PayNL.Failure.invalidTransportResponse }
        return (Data(problemBody.utf8), response)
    }
    let client = PayNL.TGU.Client(
        credentials: .bearer(try PayNL.Secret("fixture-token")),
        environment: .test,
        transport: problemTransport
    )
    do {
        _ = try await client.orders.create(input)
        throw PayNL.Failure.invalidResponse
    } catch let error as PayNL.APIError {
        guard error.httpStatus == 422,
              error.code == "PAY-1422",
              error.violations.first?.propertyPath == "amount.value",
              error.violations.first?.code == "PAY-2002",
              error.traceId == "trace-fixture"
        else { throw PayNL.Failure.invalidResponse }
    }

    let invalidResponseClient = PayNL.TGU.Client(
        credentials: .bearer(try PayNL.Secret("fixture-token")),
        environment: .test,
        transport: .init { request in
            guard let url = request.url,
                  let response = HTTPURLResponse(url: url, statusCode: 201, httpVersion: nil, headerFields: [:])
            else { throw PayNL.Failure.invalidTransportResponse }
            return (Data(#"{"id":"order-123","status":{}}"#.utf8), response)
        }
    )
    do {
        _ = try await invalidResponseClient.orders.create(input)
        throw PayNL.Failure.invalidTransportResponse
    } catch PayNL.Failure.invalidResponse {}
}
