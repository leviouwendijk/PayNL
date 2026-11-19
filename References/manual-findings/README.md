# Manual provider findings

These documents record observed API behavior found through controlled integration tests and archived production evidence. They are **not** upstream OpenAPI definitions and must not be treated as provider guarantees. Each finding states the evidence, counterexamples, limits, and any unresolved provider confirmation.

- [Idefix transaction detail: order ID returned as `id` for cancelled or expired transactions](idefix-transaction-detail-id.md)

Keep original upstream snapshots under `References/upstream/` and machine-derived inventories under `References/inventories/`. Do not amend those sources to match local observations. Do not commit customer data, credentials, raw financial records or private archive paths here.
