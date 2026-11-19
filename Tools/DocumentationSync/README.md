# PayNL reference tooling

Maintain the seven published OpenAPI contracts separately, including provenance, contract inventory and drift analysis.

From `PayNL/`:

- `python3 Tools/DocumentationSync/sync.py sync` — retrieve required contracts, publish snapshot and regenerate inventories.
- `python3 Tools/DocumentationSync/sync.py rebuild` — rebuild derived inventories offline, including first-baseline drift migration.
- `python3 Tools/DocumentationSync/sync.py audit` — read-only consistency comparison of raw specifications and stored inventories.
- `python3 Tools/DocumentationSync/sync.py verify` — read-only snapshot integrity verification.
- `python3 -m unittest discover -s Tools/DocumentationSync -p 'test_*.py'` — offline tests.

Missing upstream JSON references are reported, not invented. Acquisition integrity is distinct from contract validity. Semantic drift compares changes between successive acquisitions, and a first acquisition counts as a baseline rather than a change.
