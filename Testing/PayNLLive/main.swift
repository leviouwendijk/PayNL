import Foundation
import PayNL
import Milieu
import Darwin

func diagnose(_ error: any Error) -> String {
    if let problem = error as? PayNL.APIError {
        return "provider API error: HTTP \(problem.httpStatus), code \(problem.code ?? "unknown"), field violations \(problem.violations.count)"
    }
    if case let PayNL.Failure.http(status) = error {
        return "provider returned HTTP \(status)"
    }
    if case let DecodingError.keyNotFound(key, context) = error {
        let path = context.codingPath.map(\.stringValue).joined(separator: ".")
        return "missing documented JSON key \(key.stringValue) at \(path)"
    }
    if error is DecodingError {
        return "provider JSON does not match an SDK response model"
    }
    if error is PayNL.Failure {
        return "provider response failed SDK invariants"
    }
    return "error type: \(type(of: error))"
}

func check(_ name: String, operation: () async throws -> Int) async -> Bool {
    do {
        let count = try await operation()
        print("PASS PAY. \(name): page decoded (\(count) items)")
        return true
    } catch {
        FileHandle.standardError.write(Data("FAIL PAY. \(name): \(diagnose(error))\n".utf8))
        return false
    }
}

func run() async throws -> Bool {
    let arguments = Array(CommandLine.arguments.dropFirst())
    if arguments == ["--tgu-v2-test-create"] {
        return try await runTGUV2Creation()
    }
    guard arguments.isEmpty else {
        FileHandle.standardError.write(Data("FAIL PAY. unknown live-test arguments\n".utf8))
        return false
    }

    let atCode = try PayNL.Secret(EnvironmentExtractor.value("PAYNL_API_AT"))
    let apiToken = try PayNL.Secret(EnvironmentExtractor.value("PAYNL_API_TOKEN"))
    let gms = PayNL.GMS.Client(
        credentials: .apiToken(at_code: atCode, api_token: apiToken)
    )
    let idefix = PayNL.Idefix.Client(
        credentials: .init(username: atCode, password: apiToken)
    )
    let limit = try PayNL.PageLimit(10)
    let settlementLimit = try PayNL.GMS.SettlementLimit(10)

    var succeeded = true
    if !(await check("GMS clearings") {
        let page = try await gms.clearings.list(limit: limit)
        return page.items.count
    }) { succeeded = false }

    if !(await check("GMS settlements") {
        let page = try await gms.settlements.list(limit: settlementLimit)
        return page.items.count
    }) { succeeded = false }

    if !(await check("Idefix transactions") {
        let page = try await idefix.transactions.list(limit: limit)
        return page.transactions.count
    }) { succeeded = false }

    return succeeded
}

do {
    guard try await run() else { exit(1) }
} catch {
    FileHandle.standardError.write(Data("FAIL PAY. live probe: \(diagnose(error))\n".utf8))
    exit(1)
}
