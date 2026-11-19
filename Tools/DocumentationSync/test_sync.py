"""Offline tests for PAY. reference tooling; no HTTP requests."""

import unittest
import sync


class DocumentationSyncTests(unittest.TestCase):
    def test_json_pointer_escaping(self):
        document = {"components": {"schemas": {"A/B": {"~": 1}}}}
        self.assertTrue(sync.resolve_pointer(document, "#/components/schemas/A~1B/~0"))
        self.assertFalse(sync.resolve_pointer(document, "#/components/schemas/Unknown"))

    def test_operation_and_schema_inventory(self):
        document = {
            "openapi": "3.1.0",
            "paths": {"/v1/orders": {"post": {"operationId": "create", "responses": {"201": {}}}}},
            "components": {"schemas": {"Order": {"type": "object", "properties": {"id": {"type": "string"}}}}},
        }
        operations, schemas, unresolved, sources = sync.extract({"example.json": document})
        self.assertEqual(len(operations), 1)
        self.assertEqual(len(schemas), 1)
        self.assertFalse(unresolved)
        self.assertEqual(sources[0]["source"], "example.json")

    def test_semantic_delta(self):
        old = [{"source": "a", "method": "GET", "path": "/x", "fingerprint": "old"}]
        new = [{"source": "a", "method": "GET", "path": "/x", "fingerprint": "new"}]
        result = sync.delta(old, new, ("source", "method", "path"))
        self.assertEqual(result["modified"], [["a", "GET", "/x"]])
        self.assertFalse(result["added"])
        self.assertFalse(result["removed"])


    def test_audit_read_only_and_drift_persists(self):
        import tempfile
        from pathlib import Path
        from unittest.mock import patch

        document = {
            "openapi": "3.0.0",
            "paths": {"/orders": {"get": {"responses": {"200": {}}}}},
            "components": {"schemas": {"Order": {"type": "object"}}},
        }
        with tempfile.TemporaryDirectory() as directory:
            with patch.object(sync, "REFERENCES", Path(directory)), patch.object(sync, "SPECS", ("test.json",)):
                sync.save("upstream/openapi/test.json", sync.encode_json(document))
                self.assertEqual(sync.audit(persist=True), 0)
                baseline = sync.read_json("inventories/drift.json")
                self.assertEqual(baseline["kind"], "baseline")
                self.assertFalse(baseline["operations"]["added"])
                self.assertEqual(sync.audit(), 0)

                document["paths"]["/payments"] = {"post": {"responses": {"201": {}}}}
                sync.save("upstream/openapi/test.json", sync.encode_json(document))
                self.assertEqual(sync.audit(), 2)
                self.assertEqual(sync.audit(persist=True), 0)
                changed = sync.read_json("inventories/drift.json")
                self.assertEqual(changed["operations"]["added"], [["test.json", "POST", "/payments"]])
                self.assertEqual(sync.audit(), 0)
                self.assertEqual(sync.audit(persist=True), 0)
                self.assertEqual(sync.read_json("inventories/drift.json"), changed)

    def test_missing_ref_warning_does_not_fail_inventory(self):
        import tempfile
        from pathlib import Path
        from unittest.mock import patch

        document = {
            "openapi": "3.0.0",
            "paths": {"/orders": {"get": {"responses": {"200": {"$ref": "#/components/schemas/Missing"}}}}},
            "components": {"schemas": {}},
        }
        with tempfile.TemporaryDirectory() as directory:
            with patch.object(sync, "REFERENCES", Path(directory)), patch.object(sync, "SPECS", ("test.json",)):
                sync.save("upstream/openapi/test.json", sync.encode_json(document))
                self.assertEqual(sync.audit(persist=True), 0)
                self.assertEqual(sync.audit(), 0)
                self.assertEqual(len(sync.read_json("inventories/reference_errors.json")), 1)


if __name__ == "__main__":
    unittest.main()
