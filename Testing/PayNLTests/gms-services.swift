import Foundation
import PayNL
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

private actor GMSServiceFixture {
    private var requests: [URLRequest] = []

    func send(_ request: URLRequest) throws -> (Data, HTTPURLResponse) {
        guard request.httpMethod == "GET", let url = request.url else {
            throw PayNL.Failure.invalidResponse
        }
        requests.append(request)
        let json: String
        switch url.path {
        case "/v2/services/list":
            json = #"{"total":1,"services":[{"code":"SL-1234-5678","name":"Training","status":"ACTIVE","translations":{"name":{"nl_NL":"Training"}}}]}"#
        case "/v2/services":
            json = #"{"total":1,"count":1,"pages":1,"services":[{"code":"SL-1234-5678","name":"Training","status":"ACTIVE","testMode":true,"merchant":{"code":"M-1234-5678","name":"Example","status":"ACTIVE"},"secret":"do-not-expose"}]}"#
        case "/v2/services/SL-1234-5678":
            json = #"{"code":"SL-1234-5678","name":"Training","status":"ACTIVE","testMode":true,"secret":"do-not-expose"}"#
        case "/v2/services/SL-1234-5678/info":
            json = #"{"code":"SL-1234-5678","name":"Training","status":"ACTIVE","contactEmail":{"defaultValue":"team@example.test","value":null},"address":{"defaultValue":{"city":"Alkmaar","countryCode":"NL"},"value":null},"settings":{"verify":{"level":{"defaultValue":"FULLSERVICE","value":null}}},"paymentMethods":[{"id":10,"settings":{"mode":"default"}}],"secret":"do-not-expose"}"#
        case "/v2/services/SL-1234-5678/paymentmethods":
            json = #"{"paymentMethods":[{"id":10,"name":"iDEAL","active":true,"boarding":{"code":"BO-1234-5678","status":"ACCEPTED","completedAt":null},"settings":{"idealFailoverType":{"defaultValue":1,"value":3}}}]}"#
        default:
            throw PayNL.Failure.invalidResponse
        }
        guard let response = HTTPURLResponse(
            url: url, statusCode: 200, httpVersion: nil, headerFields: [:]
        ) else { throw PayNL.Failure.invalidTransportResponse }
        return (Data(json.utf8), response)
    }

    func verify() throws {
        guard requests.count == 5 else { throw PayNL.Failure.invalidResponse }
        let basic = "Basic " + Data("AT-1234-5678:test-token".utf8).base64EncodedString()
        guard requests.allSatisfy({
            $0.httpMethod == "GET" && $0.url?.host == "gms.pay.nl" &&
            $0.value(forHTTPHeaderField: "Authorization") == basic
        }) else { throw PayNL.Failure.invalidResponse }
        guard let listURL = requests[0].url, let browseURL = requests[1].url else {
            throw PayNL.Failure.invalidResponse
        }
        let list = URLComponents(url: listURL, resolvingAgainstBaseURL: false)?.queryItems ?? []
        guard list.contains(where: { $0.name == "status[eq]" && $0.value == "ACTIVE" }),
              listURL.path == "/v2/services/list"
        else { throw PayNL.Failure.invalidResponse }
        let browse = URLComponents(url: browseURL, resolvingAgainstBaseURL: false)?.queryItems ?? []
        guard requests[1].url?.path == "/v2/services",
              browse.contains(where: { $0.name == "merchant[eq]" && $0.value == "M-1234-5678" }),
              browse.contains(where: { $0.name == "page" && $0.value == "1" }),
              browse.contains(where: { $0.name == "limit" && $0.value == "5" }),
              requests[2].url?.path == "/v2/services/SL-1234-5678",
              requests[3].url?.path == "/v2/services/SL-1234-5678/info",
              requests[4].url?.path == "/v2/services/SL-1234-5678/paymentmethods"
        else { throw PayNL.Failure.invalidResponse }
    }
}

func runGMSServicesTests() async throws {
    let fixture = GMSServiceFixture()
    let client = PayNL.GMS.Client(
        credentials: .apiToken(
            at_code: try PayNL.Secret("AT-1234-5678"),
            api_token: try PayNL.Secret("test-token")
        ),
        transport: PayNL.Transport { request in try await fixture.send(request) }
    )
    let id = try PayNL.GMS.Service.ID("SL-1234-5678")
    let listing = try await client.services.list(status: "ACTIVE")
    guard listing.total == 1, listing.services.first?.code == id else {
        throw PayNL.Failure.invalidResponse
    }
    let page = try await client.services.browse(limit: PayNL.PageLimit(5), merchant: "M-1234-5678")
    guard page.total == 1, page.count == 1, page.items.first?.code == id,
          page.items.first?.merchant?.code == "M-1234-5678"
    else { throw PayNL.Failure.invalidResponse }
    let service = try await client.services.get(id)
    guard service.code == id, service.testMode == true else {
        throw PayNL.Failure.invalidResponse
    }
    let detail = try await client.services.info(id)
    guard detail.code == id,
          detail.contactEmail?.effectiveValue == "team@example.test",
          detail.address?.effectiveValue?.city == "Alkmaar",
          detail.paymentMethods?.first?.id == 10,
          detail.settings != nil
    else { throw PayNL.Failure.invalidResponse }
    let methods = try await client.services.paymentMethods(for: id)
    guard methods.paymentMethods.count == 1,
          methods.paymentMethods[0].id == 10,
          methods.paymentMethods[0].active == true,
          methods.paymentMethods[0].boarding?.status == "ACCEPTED"
    else { throw PayNL.Failure.invalidResponse }
    try await fixture.verify()

    let mismatch = PayNL.Transport { request in
        guard let url = request.url,
              let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: [:])
        else { throw PayNL.Failure.invalidTransportResponse }
        return (Data(#"{"code":"SL-0000-0000"}"#.utf8), response)
    }
    let wrong = PayNL.GMS.Client(credentials: .bearer(try .init("test")), transport: mismatch)
    do {
        _ = try await wrong.services.get(id)
        throw PayNL.Failure.invalidTransportResponse
    } catch PayNL.Failure.invalidResponse {}

    let badPage = PayNL.Transport { request in
        guard let url = request.url,
              let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: [:])
        else { throw PayNL.Failure.invalidTransportResponse }
        return (Data(#"{"count":2,"pages":1,"services":[{"code":"SL-1234-5678"}]}"#.utf8), response)
    }
    let invalid = PayNL.GMS.Client(credentials: .bearer(try .init("test")), transport: badPage)
    do {
        _ = try await invalid.services.browse()
        throw PayNL.Failure.invalidTransportResponse
    } catch PayNL.Failure.invalidResponse {}

    guard (try? PayNL.GMS.Service.ID("not-a-service")) == nil else {
        throw PayNL.Failure.invalidResponse
    }
}
