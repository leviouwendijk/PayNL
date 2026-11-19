#!/usr/bin/env python3
"""PAY. public reference acquisition and offline contract verification."""

import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import tempfile
import time
from urllib.parse import urlsplit
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[2]
REFERENCES = ROOT / "References"
SPECS = (
    "pay-card-payments.json",
    "pay-clearing-and-invoicing-apis.json",
    "pay-gmsapi.json",
    "pay-idefix-rest.json",
    "pay-idefix-trx.json",
    "pay-terminal-payments.json",
    "pay-tgu.json",
)
PAGES = (
    "api-defenition",
    "platform",
    "how-to-use",
    "integration-guides",
)
METHODS = {"get", "post", "put", "patch", "delete", "head", "options", "trace"}
LIMIT = 64 * 1024 * 1024


def encode_json(value):
    return (json.dumps(value, ensure_ascii=False, sort_keys=True, indent=4) + "\n").encode("utf-8")


def fingerprint(value):
    return hashlib.sha256(encode_json(value)).hexdigest()


def save(relative, data):
    target = REFERENCES / relative
    target.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(dir=target.parent, delete=False) as handle:
        temporary = Path(handle.name)
        try:
            handle.write(data)
        except BaseException:
            temporary.unlink(missing_ok=True)
            raise
    os.replace(temporary, target)


def read_json(relative):
    path = REFERENCES / relative
    return json.loads(path.read_bytes()) if path.exists() else None


def get(url):
    parsed = urlsplit(url)
    if parsed.scheme != "https" or parsed.hostname != "developer.pay.nl":
        raise ValueError("Unapproved source URL")
    for attempt in range(3):
        try:
            request = Request(url, headers={"User-Agent": "PayNLReferenceSync/1.0"})
            with urlopen(request, timeout=40) as response:
                final = urlsplit(response.geturl())
                if final.scheme != "https" or final.hostname != "developer.pay.nl":
                    raise ValueError("Redirect outside approved host")
                result = response.read(LIMIT + 1)
                if not result or len(result) > LIMIT:
                    raise ValueError("Empty or oversized response")
                return result
        except (OSError, ValueError) as error:
            if attempt == 2:
                raise RuntimeError(str(error)) from error
            time.sleep(attempt + 1)


def pointers(document):
    stack = [document]
    while stack:
        current = stack.pop()
        if isinstance(current, dict):
            if isinstance(current.get("$ref"), str):
                yield current["$ref"]
            stack.extend(current.values())
        elif isinstance(current, list):
            stack.extend(current)


def resolve_pointer(document, reference):
    if not reference.startswith("#/"):
        return False
    current = document
    try:
        for part in reference[2:].split("/"):
            part = part.replace("~1", "/").replace("~0", "~")
            current = current[int(part)] if isinstance(current, list) else current[part]
    except (KeyError, IndexError, ValueError, TypeError):
        return False
    return True


def extract(specs):
    operations = []
    schemas = []
    references = []
    source_summaries = []
    for filename, document in sorted(specs.items()):
        if not isinstance(document, dict) or not str(document.get("openapi", "")).startswith("3."):
            raise ValueError(f"{filename}: expected OpenAPI 3.x")
        if not isinstance(document.get("paths"), dict) or not isinstance(document.get("components"), dict):
            raise ValueError(f"{filename}: missing paths/components")
        for path, item in sorted(document["paths"].items()):
            if not isinstance(item, dict):
                raise ValueError(f"{filename}: invalid path item {path}")
            for method, definition in sorted(item.items()):
                if method.lower() not in METHODS:
                    continue
                if not isinstance(definition, dict):
                    raise ValueError(f"{filename}: invalid operation {method} {path}")
                operations.append({
                    "source": filename,
                    "method": method.upper(),
                    "path": path,
                    "operation_id": definition.get("operationId"),
                    "tags": definition.get("tags", []),
                    "deprecated": definition.get("deprecated", False),
                    "responses": sorted((definition.get("responses") or {}).keys()),
                    "security": definition.get("security", document.get("security")),
                    "fingerprint": fingerprint(definition),
                })
        definitions = document["components"].get("schemas", {})
        if not isinstance(definitions, dict):
            raise ValueError(f"{filename}: invalid components.schemas")
        for name, definition in sorted(definitions.items()):
            schemas.append({
                "source": filename,
                "name": name,
                "fingerprint": fingerprint(definition),
                "properties": sorted((definition.get("properties") or {}).keys()) if isinstance(definition, dict) else [],
                "required": sorted(definition.get("required") or []) if isinstance(definition, dict) else [],
            })
        for reference in sorted(set(pointers(document))):
            if not resolve_pointer(document, reference):
                references.append({"source": filename, "ref": reference, "kind": "external" if not reference.startswith("#/") else "unresolved_internal"})
        source_summaries.append({
            "source": filename,
            "openapi": document["openapi"],
            "version": (document.get("info") or {}).get("version"),
            "title": (document.get("info") or {}).get("title"),
            "servers": document.get("servers", []),
            "security_schemes": sorted((document["components"].get("securitySchemes") or {}).keys()),
        })
    return operations, schemas, references, source_summaries


def delta(old, new, identity):
    previous = {tuple(item[key] for key in identity): item["fingerprint"] for item in (old or [])}
    current = {tuple(item[key] for key in identity): item["fingerprint"] for item in new}
    return {
        "added": [list(key) for key in sorted(current.keys() - previous.keys())],
        "removed": [list(key) for key in sorted(previous.keys() - current.keys())],
        "modified": [list(key) for key in sorted(previous.keys() & current.keys()) if previous[key] != current[key]],
        "first_snapshot": old is None,
    }


def audit(persist=False):
    """Check the current inventory without writes, or rebuild it explicitly."""
    specs = {}
    for filename in SPECS:
        path = REFERENCES / "upstream/openapi" / filename
        if not path.is_file():
            raise FileNotFoundError(f"Missing required specification: {path}")
        specs[filename] = json.loads(path.read_bytes())

    operations, schemas, references, sources = extract(specs)
    previous = {
        "operations.json": read_json("inventories/operations.json"),
        "schemas.json": read_json("inventories/schemas.json"),
        "reference_errors.json": read_json("inventories/reference_errors.json"),
        "sources.json": read_json("inventories/sources.json"),
    }
    current = {
        "operations.json": operations,
        "schemas.json": schemas,
        "reference_errors.json": references,
        "sources.json": sources,
    }
    stale = [name for name in current if previous[name] != current[name]]

    if not persist:
        for name in stale:
            print(f"STALE: References/inventories/{name}; run 'rebuild'")
        print(
            f"PAY. audit: {len(specs)} specs; {len(operations)} operations; "
            f"{len(schemas)} schemas; upstream reference warnings={len(references)}; "
            f"stale inventories={len(stale)}"
        )
        return 2 if stale else 0

    older_drift = read_json("inventories/drift.json")
    old_operations = previous["operations.json"]
    old_schemas = previous["schemas.json"]

    if old_operations is None and old_schemas is None:
        drift = {
            "kind": "baseline",
            "operations": {"first_snapshot": True, "added": [], "removed": [], "modified": []},
            "schemas": {"first_snapshot": True, "added": [], "removed": [], "modified": []},
        }
    elif old_operations != operations or old_schemas != schemas:
        drift = {
            "kind": "change",
            "operations": delta(old_operations, operations, ("source", "method", "path")),
            "schemas": delta(old_schemas, schemas, ("source", "name")),
        }
    elif older_drift is None or (
        older_drift.get("operations", {}).get("first_snapshot")
        and older_drift.get("schemas", {}).get("first_snapshot")
    ):
        # Migrate the original first-import-as-additions representation.
        drift = {
            "kind": "baseline",
            "operations": {"first_snapshot": True, "added": [], "removed": [], "modified": []},
            "schemas": {"first_snapshot": True, "added": [], "removed": [], "modified": []},
        }
    else:
        # Preserve the latest real change until another snapshot differs.
        drift = None

    for name, value in current.items():
        save("inventories/" + name, encode_json(value))
    if drift is not None:
        save("inventories/drift.json", encode_json(drift))

    lines = [
        "# PAY. API contract inventory", "",
        f"- OpenAPI documents: {len(specs)}",
        f"- Operations: {len(operations)}",
        f"- Schemas: {len(schemas)}",
        f"- Unresolved/external references: {len(references)}", "",
        "## Per-specification coverage", "",
    ]
    for source in sources:
        name = source["source"]
        line_operations = sum(item["source"] == name for item in operations)
        line_schemas = sum(item["source"] == name for item in schemas)
        lines.append(f"- `{name}`: {line_operations} operations, {line_schemas} schemas; OpenAPI {source['openapi']}")
    lines.extend(["", "## Unresolved upstream references", ""])
    lines.extend(f"- `{item['source']}`: `{item['ref']}` ({item['kind']})" for item in references)
    if not references:
        lines.append("None.")
    lines.extend([
        "", "## Limitations", "",
        "Download integrity and reference validity are separate. Unresolved upstream references are reported, not fabricated.",
        "Full OpenAPI semantic validation and live provider compatibility testing are not performed.", "",
    ])
    save("inventories/coverage.md", "\n".join(lines).encode())
    print(
        f"PAY. inventory: {len(specs)} specs; {len(operations)} operations; "
        f"{len(schemas)} schemas; upstream reference warnings={len(references)}"
    )
    return 0


def verify():
    manifest = read_json("manifests/snapshot.json")
    if not manifest:
        raise FileNotFoundError("No snapshot; run sync first")
    failures = []
    warnings = []
    for source in manifest["sources"]:
        if source["status"] != "ok":
            target = failures if source.get("required", True) else warnings
            target.append(source["path"] + ": download failed")
            continue
        path = REFERENCES / source["path"]
        if not path.is_file():
            failures.append(source["path"] + ": missing file")
            continue
        content = path.read_bytes()
        if len(content) != source["bytes"] or hashlib.sha256(content).hexdigest() != source["sha256"]:
            failures.append(source["path"] + ": digest/size mismatch")
    names = {Path(item["path"]).name for item in manifest["sources"] if item["status"] == "ok"}
    for name in SPECS:
        if name not in names:
            failures.append(name + ": required spec missing from snapshot")
    for issue in warnings:
        print("WARN:", issue)
    for issue in failures:
        print("FAIL:", issue)
    print(f"PAY. verify: {len(manifest['sources'])} sources; failures={len(failures)}; optional warnings={len(warnings)}")
    return 2 if failures else 0


def sync():
    candidates = [(f"https://developer.pay.nl/openapi/{name}", f"upstream/openapi/{name}", True) for name in SPECS]
    candidates += [(f"https://developer.pay.nl/v4.0/docs/{name}", f"upstream/portal/{name}.html", False) for name in PAGES]
    entries = []
    staged = {}
    for url, path, required in candidates:
        try:
            content = get(url)
            if required:
                document = json.loads(content)
                if not isinstance(document, dict) or not str(document.get("openapi", "")).startswith("3."):
                    raise ValueError("Expected an OpenAPI 3.x JSON specification")
            staged[path] = content
            entries.append({"url": url, "path": path, "required": required, "status": "ok", "bytes": len(content), "sha256": hashlib.sha256(content).hexdigest()})
        except Exception as error:
            entries.append({"url": url, "path": path, "required": required, "status": "failed", "error": str(error)})
        time.sleep(0.2)
    bad = [item for item in entries if item["status"] != "ok" and item["required"]]
    attempt = {"captured_at": datetime.datetime.now(datetime.timezone.utc).isoformat(), "provider": "paynl", "sources": entries, "status": "failed" if bad else ("partial" if any(item["status"] != "ok" for item in entries) else "complete")}
    save("manifests/latest_attempt.json", encode_json(attempt))
    if bad:
        print("Required source failure: previous snapshot left untouched")
        return 2
    try:
        specs = {name: json.loads(staged[f"upstream/openapi/{name}"]) for name in SPECS}
        extract(specs)
    except ValueError as error:
        print("Invalid contract:", error)
        return 2
    for path, content in staged.items():
        save(path, content)
    save("manifests/snapshot.json", encode_json(attempt))
    return audit(persist=True) or verify()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("sync", "rebuild", "audit", "verify"))
    command = parser.parse_args().command
    return {"sync": sync, "rebuild": lambda: audit(persist=True), "audit": audit, "verify": verify}[command]()


if __name__ == "__main__":
    raise SystemExit(main())
