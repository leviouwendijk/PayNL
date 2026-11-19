import Foundation
import PayNL

func runWireKeyConvergenceTests() throws {
    let decoder = JSONDecoder()

    let transaction = try decoder.decode(
        PayNL.Idefix.Transaction.self,
        from: Data(#"{"id":"EX-1234-5678-9012","orderId":"INV-001","amountRefunded":{"value":125,"currency":"EUR"},"createdAt":"2024-05-26T01:52:59+02:00"}"#.utf8)
    )
    guard transaction.orderId == "INV-001",
          transaction.amountRefunded?.value == 125,
          transaction.createdAt == "2024-05-26T01:52:59+02:00" else {
        throw PayNL.Failure.invalidResponse
    }

    let clearing = try decoder.decode(
        PayNL.GMS.Clearing.self,
        from: Data(#"{"id":"CLEARING-1","settlementCode":"SETTLEMENT-1","periodType":"MONTH","turnoverGroups":[{"code":"GROUP"}],"rollingReserve":{"value":200,"currency":"EUR"}}"#.utf8)
    )
    guard clearing.settlementCode?.raw == "SETTLEMENT-1",
          clearing.periodType == "MONTH",
          clearing.turnoverGroups?.first?.code == "GROUP",
          clearing.rollingReserve?.value == 200 else {
        throw PayNL.Failure.invalidResponse
    }

    let page = try decoder.decode(
        PayNL.Idefix.Page.self,
        from: Data(#"{"total":1,"count":1,"pages":1,"transactions":[{"id":"EX-1234-5678-9012"}]}"#.utf8)
    )
    guard page.transactions.count == 1, page.count == 1 else {
        throw PayNL.Failure.invalidResponse
    }

    let noCoercion = try decoder.decode(
        PayNL.Idefix.Transaction.self,
        from: Data(#"{"id":"EX-1234-5678-9012","order_id":"Not provider wire format"}"#.utf8)
    )
    guard noCoercion.orderId == nil else {
        throw PayNL.Failure.invalidResponse
    }
}
