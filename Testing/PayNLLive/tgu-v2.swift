import Foundation
import Milieu
import PayNL

/// Creates exactly one PAY. test-environment order when explicitly invoked.
/// Does not complete payment, follow checkout URLs or contact a callback URL.
func runTGUV2Creation() async throws -> Bool {
    let atCode = try PayNL.Secret(EnvironmentExtractor.value("PAYNL_API_AT"))
    let token = try PayNL.Secret(EnvironmentExtractor.value("PAYNL_API_TOKEN"))
    let serviceID = try PayNL.TGU.ServiceID(
        EnvironmentExtractor.value("PAYNL_SERVICE_ID")
    )

    let reference = try PayNL.TGU.Order.Reference(
        "SDK-" + UUID().uuidString.replacingOccurrences(of: "-", with: "")
    )
    let input = PayNL.TGU.Order.Input(
        serviceId: serviceID,
        amount: try .init(value: 150, currency: PayNL.Currency("EUR")),
        description: "Swift SDK contract verification",
        reference: reference
    )

    let client = PayNL.TGU.Client(
        credentials: .basic(username: atCode, password: token),
        environment: .test
    )

    let created = try await client.orders.create(input)
    print("PAY. TGU v2 test order created: \(created.id.raw)")
    print("PAY. TGU v2 test reference: \(reference.raw)")

    guard created.integration?.test == true else {
        throw PayNL.Failure.invalidResponse
    }

    let checkout = try created.requireRedirectURL()
    guard checkout.scheme?.lowercased() == "https" else {
        throw PayNL.Failure.invalidResponse
    }

    let retrieved = try await client.orders.status(created.id)
    guard retrieved.id == created.id,
          retrieved.integration?.test == true,
          retrieved.status?.isIdentified == true
    else {
        throw PayNL.Failure.invalidResponse
    }

    print("PASS PAY. TGU v2: test order created, HTTPS checkout link validated, status retrieved")
    print("PAY. order status: \(retrieved.status?.action ?? "unspecified")")
    return true
}
