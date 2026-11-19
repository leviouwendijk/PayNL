# Idefix `/v2/transactions/{transactionId}`: order ID returned in `id`

**Evidence status:** observed empirically on 2026-11-07; **provider confirmation outstanding**. This is a locally observed response pattern, **not** a documented promise or a verified equivalence between an EX transaction and an order.

## Scope and reproducibility

A completed, SHA-256-verified production acquisition of `GET /v2/transactions` and 420 individual detail responses yielded the following pattern:

| Browse status (code/action/phase) | Count | Detail `id` compared to browse EX code |
| --- | ---: | --- |
| `100/PAID/SUCCESS` | 244 | Matches EX code |
| `-80/CANCEL/EXPIRED` | 154 | Equals the order ID; differs from EX code |
| `-90/CANCEL/CANCELLED` | 22 | Equals the order ID; differs from EX code |

The 176 exceptional detail responses have the expected `orderId` and agree with browse records on amount, currency, status, refunded amount/currency, reference and description. Their `createdAt` timestamps, normalized to instants, match in 158 cases and differ by exactly -1 second in 18. Their `completedDate` could not be compared (unavailable). All 176 original detail requests used an order ID. A follow-up sample made **five fresh GET requests by the original EX codes**; all five again returned the corresponding order ID in both `id` and `orderId`, not the requested EX code, and financial fields agreed.

Synthetic shape (never confuse the two identifiers):

```json
{
    "browse": {
        "id": "EX-1234-5678-9012",
        "orderId": "ORDER-ABC",
        "status": { "code": -80, "action": "CANCEL", "phase": "EXPIRED" }
    },
    "detail": {
        "id": "ORDER-ABC",
        "orderId": "ORDER-ABC",
        "status": { "code": -80, "action": "CANCEL", "phase": "EXPIRED" }
    }
}
```

This is an **observed status-correlated pattern**, not a universal rule for all PAY. accounts or versions. Other account histories, status transitions, or future API behavior may differ. Further confirmation by PAY. is required. The order-ID equality does not prove that two identifier strings are interchangeable, nor that duplicate or separate payment attempts can be ruled out.

## Published contract comparison

- [Transaction:Browse](https://developer.pay.nl/reference/get_transactions) exposes transaction IDs and order IDs.
- [Transaction:Info](https://developer.pay.nl/reference/get_transactions-transactionid) accepts either an EX code or an order ID in the detail lookup path, but does not describe the above status-conditioned response-`id` substitution.
- [PAY. transaction overview](https://support.pay.nl/en/knowledge/transaction-overview) lists status `-80` (expired) and `-90` (cancelled).
- [PAY. transaction descriptions](https://support.pay.nl/en/knowledge/transaction-overview) distinguish EX transaction codes from order IDs.

No explicit description of this substitution was found in the reviewed public reference pages or the locally archived PAY. OpenAPI sources as of the observation date. Absence from those sources is **not** proof of absence from every version of PAY. documentation.

## Library handling

- `PayNL.Idefix.Transaction.id` retains the exact provider value. `idRepresentation` describes whether it is shaped like an EX code or exactly equals the response's `orderId`; it does not synthesize or repair an ID.
- Banking preserves `SourceDetailMismatch` and `SourceManifest.identityReconciliation = unresolved` in the original run. It evaluates the observed pattern as **derived classification** during a read-only offline audit; only exact terminal statuses and strict field/time checks qualify.
- Report `order_id_returned_as_transaction_id` is an explanation of the response shape, **not** permission to attribute the detail to a particular EX payment or to post revenue/settlement records automatically.
- Audit outputs are separate, versioned (`schemaVersion: 2`), timestamped records tied to the raw source manifest SHA-256. Original HTTP response bodies, hashes, and manifests must never be rewritten as part of the interpretation update.

## Follow-up

Request written clarification from PAY. technical support on whether expired/cancelled detail lookups intentionally return `id = orderId` even when addressed by EX code, and whether a stable canonical EX identifier exists for these cases. Keep any provider statement separately and update this finding's status when independently verified.
