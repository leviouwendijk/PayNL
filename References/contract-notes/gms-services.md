# GMS services (sales locations): SDK contract

Reviewed: 2026-11-11. Source: archived `References/upstream/openapi/pay-gmsapi.json` and official PAY. API reference.

## Read-only endpoints

- `PayNL.GMS.Client.services.list(merchant:status:excludingStatus:)`: GET `https://gms.pay.nl/v2/services/list`, compact unpaginated records and optional total. Filters use `merchant[eq]`, `status[eq]`, `status[neq]`.
- `services.browse(page:limit:merchant:)`: GET `/v2/services`, full service records, page/count/pages/total. Uses `merchant[eq]`.
- `services.get(_:)`: GET `/v2/services/{serviceId}`, validates the returned SL-code.
- `services.info(_:)`: GET `/v2/services/{serviceId}/info`, validates the returned SL-code. Supported fields have typed models; rich configuration retains `Primitives.JSONValue` rather than assuming a uniform nested settings schema.
- `services.paymentMethods(for:merchant:)`: GET `/v2/services/{serviceId}/paymentmethods`, preserving each method's ID, activation state, boarding state, and JSON settings.

The ID type is shared with the verified TGU v2 order request (`PayNL.TGU.ServiceID`). These methods reuse the existing GMS authentication and transport. No service mutation endpoints are implemented in this pass.

**Security:** The GMS API's service and info responses include a `secret` field. It is intentionally omitted from the SDK's public service models, avoiding accidental printing or propagation. Unrecognized provider fields are ignored by `Decodable`.

**Known schema inconsistencies:** Published examples sometimes represent `_links` as an object while the schema describes an array, and `publication.aliasUrls[].url` has conflicting shapes. These fields are not promised as strongly typed SDK properties in this pass. The service `info` settings and translations are flexible JSON values. Fixture tests exercise the five paths, credential propagation, query encoding, identity checks, and invalid paging. **Live GMS service reads have not yet been verified by this change.**

## References

- https://developer.pay.nl/reference/service_services_list_get
- https://developer.pay.nl/reference/service_payment_methods_get
- https://developer.pay.nl/docs/services-sales-locations
- `References/upstream/openapi/pay-gmsapi.json`
