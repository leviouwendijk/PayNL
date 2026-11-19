# TGU order API v2: contract coverage and limitations

Status: implementation and fixtures only. Not yet live-verified against PAY. v2.
Reviewed: 2026-11-11.

## Version boundary

- API 4.0 order creation: `POST https://connect.pay.nl/v2/orders`.
- API 4.0 status: `GET https://connect.pay.nl/v2/orders/{id}/status`.
- `Pay-Environment: test|prod` selects the order environment on v2 creation.
- `locale` and `pointOfInteraction` are top-level v2 order input fields.
- The existing upstream `pay-tgu.json` snapshot documents **v1** routes. It is archived reference evidence, not a v2 schema; the seven-spec / 237-operation inventory should NOT be incremented or rewritten to claim v2 coverage.

## SDK coverage

- Typed order input: service ID, minor-unit amount and currency, reference, payment method ID, optional provider-specific payment input (`Primitives.JSONValue`), customer/company, addresses, products (including decimal quantity and VAT), optimization/collector metadata, split payments, stats and transfer data.
- Typed output: identity, status, amounts, payments, integration, splits, statistics, timestamps and dynamically keyed links.
- Error envelope: RFC 7807-style type/title/detail/code/trace and field violations; unrecognized/empty bodies fall back to `PayNL.Failure.http(status:)`.
- Create response must identify its status and must not contradict the request's supplied service ID, reference, amount or currency. Missing optional echoed fields remain legal. Checkout redirect is checked separately using `requireRedirectURL()`.
- Transport, creation, validation, and error fixtures are mocked. A passing fixture does not prove upstream field compatibility.

## Open gaps

- The public v2 reference shows top-level types but does not publish all nested schema details inline. Nested fields were cross-checked against the archived v1 TGU OpenAPI only where plausible; **this is an assumption requiring test-environment verification**, not a guarantee of v2 equivalence.
- Provider-specific payment-method input unions are intentionally represented as `JSONValue`, not fictional universal typed fields; add separate typed cases after verifying each method's v2 contract.
- No live order has been created in this pass. No customer data or credentials are stored in these notes.
- Do not infer all `Order.Output` properties are mandatory or that all payment links contain a redirect.

## Opt-in live test

The `t_paynl_live` executable retains its existing read-only default. An explicit `--tgu-v2-test-create` argument instead creates exactly one 150-minor-unit EUR order with `Pay-Environment: test`, checks the response test flag and HTTPS redirect, and retrieves the order status.

Required environment values: `PAYNL_API_AT`, `PAYNL_API_TOKEN`, and `PAYNL_TGU_SERVICE_ID`. The latter must identify the intended PAY. sales location. The test uses Basic authentication and generates a unique synthetic order reference. It does not open the checkout link or initiate payment completion. Do not use production-mode fallback for this probe.

Command after configuring the environment: `with_dev_environment swift run t_paynl_live --tgu-v2-test-create`.

This is an opt-in write operation against PAY.'s test environment, not part of the ordinary fixture suite. Merely building the executable does not perform the request. Record actual live findings separately after execution.

## Sources

- https://developer.pay.nl/v4.0/reference/api_create_order-1
- https://developer.pay.nl/changelog/introduction-of-v2
- https://developer.pay.nl/docs/split-payments
- Archived local `References/upstream/openapi/pay-tgu.json` (v1 only)
