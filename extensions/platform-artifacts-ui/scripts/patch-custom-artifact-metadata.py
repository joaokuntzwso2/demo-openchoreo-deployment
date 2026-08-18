#!/usr/bin/env python3
from __future__ import annotations

import json
import re
import sys
from dataclasses import dataclass
from pathlib import Path

LABEL_KEY = "demo.openchoreo.dev/custom-artifact"
DISPLAY_KEY = "demo.openchoreo.dev/display-name"
CATEGORY_KEY = "demo.openchoreo.dev/category"
DESCRIPTION_KEY = "demo.openchoreo.dev/description"

@dataclass(frozen=True)
class Meta:
    display: str
    category: str
    description: str

# Source-controlled ownership registry. The UI itself does not use this list; it
# discovers all live OpenChoreo objects carrying LABEL_KEY=true. This registry is
# only used to stamp the demo's existing manifests during repository integration.
TARGETS: dict[str, dict[tuple[str, str], Meta]] = {
    "platform/01-regulated-platform-project-type.yaml": {
        ("ClusterProjectType", "regulated-platform"): Meta(
            "Regulated Platform", "Golden Path",
            "Project golden path that materializes regulated environment cells with quotas, defaults, networking and audit controls.",
        ),
    },
    "platform/02-environments-pipeline.yaml": {
        ("Environment", "development"): Meta("Development", "Delivery Environment", "OpenChoreo development environment used by the platform-standard delivery pipeline."),
        ("Environment", "staging"): Meta("Staging", "Delivery Environment", "OpenChoreo staging environment used by the platform-standard delivery pipeline."),
        ("Environment", "production"): Meta("Production", "Delivery Environment", "OpenChoreo production environment used by the platform-standard delivery pipeline."),
        ("DeploymentPipeline", "platform-standard"): Meta("Standard Delivery Pipeline", "Delivery", "Development to staging to production delivery topology for the regulated demo projects."),
    },
    "platform/04-alert-notification-channels.yaml": {
        ("ObservabilityAlertsNotificationChannel", "platform-webhook-development"): Meta("Development Alert Webhook", "Observability", "Environment-specific alert notification channel for local showcase evidence."),
        ("ObservabilityAlertsNotificationChannel", "platform-webhook-staging"): Meta("Staging Alert Webhook", "Observability", "Environment-specific alert notification channel for local showcase evidence."),
        ("ObservabilityAlertsNotificationChannel", "platform-webhook-production"): Meta("Production Alert Webhook", "Observability", "Environment-specific alert notification channel for local showcase evidence."),
    },
    "platform/05-resource-type.yaml": {
        ("ClusterResourceType", "platform-valkey-cache"): Meta("Platform Valkey Cache", "Managed Resource", "Platform-managed Valkey resource abstraction consumed through OpenChoreo resource bindings."),
    },
    "platform/06-payment-cache.yaml": {
        ("Resource", "payment-idempotency-cache"): Meta("Payment Idempotency Cache", "Managed Resource Instance", "Managed cache instance consumed by payments-service through an OpenChoreo Resource dependency."),
    },
    "platform/07-platform-policy-workflow.yaml": {
        ("Workflow", "platform-policy-gate"): Meta("Platform Policy Gate", "Governance Workflow", "Namespace-scoped release policy workflow used to demonstrate policy evidence and rejection paths."),
    },
    "platform/09-bank-runtime-hardening-trait.yaml": {
        ("ClusterTrait", "bank-runtime-hardening"): Meta("Bank Runtime Hardening", "Security & Runtime Policy", "Reusable runtime security baseline including seccomp, capability drop, privilege restrictions and disruption protection."),
    },
    "platform/10-regulated-release-gate-clusterworkflow.yaml": {
        ("ClusterWorkflow", "regulated-release-gate"): Meta("Regulated Release Gate", "Governance Workflow", "Reusable release control validating security, risk, change-ticket and approval evidence."),
    },
    "platform/11-regulated-service-clustercomponenttype.json": {
        ("ClusterComponentType", "regulated-service"): Meta("Regulated Service", "Golden Path", "Reusable service golden path that composes deployment behavior with the bank runtime hardening trait."),
    },
    "platform/authz/roles-bindings.yaml": {
        ("AuthzRole", "platform-auditor"): Meta("Platform Auditor", "Access Control", "Read-oriented OpenChoreo role for application, release and observability evidence."),
        ("ClusterAuthzRoleBinding", "platform-demo-developers"): Meta("Platform Demo Developers", "Access Control", "Developer authorization binding with environment-aware restrictions around production changes."),
        ("AuthzRoleBinding", "platform-demo-auditors"): Meta("Platform Demo Auditors", "Access Control", "Binds the showcase auditor subject to the platform-auditor role."),
    },
}


def yaml_quote(value: str) -> str:
    # JSON strings are valid YAML scalar syntax and handle punctuation safely.
    return json.dumps(value, ensure_ascii=False)


def line_indent(line: str) -> int:
    return len(line) - len(line.lstrip(" "))


def top_level_value(lines: list[str], key: str) -> str | None:
    rx = re.compile(rf"^{re.escape(key)}:\s*[\"']?([^\"'#\s]+)")
    for line in lines:
        m = rx.match(line)
        if m:
            return m.group(1).strip()
    return None


def metadata_bounds(lines: list[str]) -> tuple[int, int] | None:
    start = next((i for i, l in enumerate(lines) if re.match(r"^metadata:\s*(?:#.*)?$", l)), None)
    if start is None:
        return None
    end = len(lines)
    for i in range(start + 1, len(lines)):
        stripped = lines[i].strip()
        if not stripped or stripped.startswith("#"):
            continue
        if line_indent(lines[i]) == 0:
            end = i
            break
    return start, end


def metadata_name(lines: list[str], start: int, end: int) -> str | None:
    for line in lines[start + 1:end]:
        m = re.match(r"^\s{2}name:\s*[\"']?([^\"'#\s]+)", line)
        if m:
            return m.group(1).strip()
    return None


def find_child_block(lines: list[str], start: int, end: int, key: str) -> tuple[int, int] | None:
    rx = re.compile(rf"^\s{{2}}{re.escape(key)}:\s*(?:#.*)?$")
    idx = next((i for i in range(start + 1, end) if rx.match(lines[i])), None)
    if idx is None:
        return None
    block_end = end
    for i in range(idx + 1, end):
        stripped = lines[i].strip()
        if not stripped or stripped.startswith("#"):
            continue
        if line_indent(lines[i]) <= 2:
            block_end = i
            break
    return idx, block_end


def get_mapping_value(lines: list[str], metadata_start: int, metadata_end: int, block: str, key: str) -> str | None:
    block_info = find_child_block(lines, metadata_start, metadata_end, block)
    if not block_info:
        return None
    b_start, b_end = block_info
    rx = re.compile(rf"^\s{{4}}{re.escape(key)}:\s*(.*?)\s*$")
    for i in range(b_start + 1, b_end):
        m = rx.match(lines[i])
        if not m:
            continue
        raw = m.group(1).strip()
        if raw.startswith(("\"", "'")):
            try:
                if raw.startswith("\""):
                    return json.loads(raw)
            except json.JSONDecodeError:
                pass
            if raw.startswith("'") and raw.endswith("'"):
                return raw[1:-1].replace("''", "'")
        return raw.split(" #", 1)[0].strip()
    return None


def set_mapping_value(lines: list[str], metadata_start: int, metadata_end: int, block: str, key: str, value: str) -> tuple[list[str], int]:
    # Replace existing key if present.
    block_info = find_child_block(lines, metadata_start, metadata_end, block)
    if block_info:
        b_start, b_end = block_info
        key_rx = re.compile(rf"^\s{{4}}{re.escape(key)}:\s*")
        for i in range(b_start + 1, b_end):
            if key_rx.match(lines[i]):
                lines[i] = f"    {key}: {yaml_quote(value)}"
                return lines, metadata_end
        lines.insert(b_end, f"    {key}: {yaml_quote(value)}")
        return lines, metadata_end + 1

    # Create block after metadata.name when possible, otherwise right after metadata.
    insert_at = metadata_start + 1
    for i in range(metadata_start + 1, metadata_end):
        if re.match(r"^\s{2}name:\s*", lines[i]):
            insert_at = i + 1
            break
    lines[insert_at:insert_at] = [f"  {block}:", f"    {key}: {yaml_quote(value)}"]
    return lines, metadata_end + 2


def patch_yaml_document(doc: str, targets: dict[tuple[str, str], Meta], check: bool) -> tuple[str, set[tuple[str, str]]]:
    had_trailing_newline = doc.endswith("\n")
    lines = doc.splitlines()
    kind = top_level_value(lines, "kind")
    bounds = metadata_bounds(lines)
    if not kind or not bounds:
        return doc, set()
    m_start, m_end = bounds
    name = metadata_name(lines, m_start, m_end)
    if not name or (kind, name) not in targets:
        return doc, set()

    meta = targets[(kind, name)]
    if check:
        actual_label = get_mapping_value(lines, m_start, m_end, "labels", LABEL_KEY)
        expected_annotations = {
            DISPLAY_KEY: meta.display,
            CATEGORY_KEY: meta.category,
            DESCRIPTION_KEY: meta.description,
        }
        problems: list[str] = []
        if actual_label != "true":
            problems.append(f"{LABEL_KEY}={actual_label!r}")
        for akey, expected in expected_annotations.items():
            actual = get_mapping_value(lines, m_start, m_end, "annotations", akey)
            if actual != expected:
                problems.append(f"{akey}={actual!r}")
        if problems:
            raise SystemExit(f"ERROR: {kind}/{name} has incorrect source-controlled Platform Artifacts metadata: {', '.join(problems)}")
        return doc, {(kind, name)}

    lines, m_end = set_mapping_value(lines, m_start, m_end, "labels", LABEL_KEY, "true")
    for key, value in ((DISPLAY_KEY, meta.display), (CATEGORY_KEY, meta.category), (DESCRIPTION_KEY, meta.description)):
        bounds = metadata_bounds(lines)
        assert bounds is not None
        m_start, m_end = bounds
        lines, m_end = set_mapping_value(lines, m_start, m_end, "annotations", key, value)

    rendered = "\n".join(lines)
    if had_trailing_newline and not rendered.endswith("\n"):
        rendered += "\n"
    return rendered, {(kind, name)}


def patch_yaml_file(path: Path, targets: dict[tuple[str, str], Meta], check: bool) -> None:
    original = path.read_text()
    # Keep document separators exactly as separators while patching each document.
    parts = re.split(r"(?m)^(---\s*)$", original)
    seen: set[tuple[str, str]] = set()
    for i in range(0, len(parts), 2):
        patched, matched = patch_yaml_document(parts[i], targets, check)
        parts[i] = patched
        seen |= matched
    missing = set(targets) - seen
    if missing:
        rendered = ", ".join(f"{k}/{n}" for k, n in sorted(missing))
        raise SystemExit(f"ERROR: expected Platform Artifacts object(s) not found in {path}: {rendered}")
    if not check:
        text = "".join(parts)
        if original.endswith("\n") and not text.endswith("\n"):
            text += "\n"
        path.write_text(text)


def patch_json_file(path: Path, targets: dict[tuple[str, str], Meta], check: bool) -> None:
    data = json.loads(path.read_text())
    documents = data if isinstance(data, list) else [data]
    seen: set[tuple[str, str]] = set()
    for obj in documents:
        if not isinstance(obj, dict):
            continue
        kind = obj.get("kind")
        metadata = obj.get("metadata") or {}
        name = metadata.get("name")
        key = (kind, name)
        if key not in targets:
            continue
        seen.add(key)
        meta = targets[key]
        if check:
            labels = metadata.get("labels") or {}
            annotations = metadata.get("annotations") or {}
            if labels.get(LABEL_KEY) != "true":
                raise SystemExit(f"ERROR: {kind}/{name} is missing {LABEL_KEY}=true in {path}")
            expected = {DISPLAY_KEY: meta.display, CATEGORY_KEY: meta.category, DESCRIPTION_KEY: meta.description}
            for akey, aval in expected.items():
                if annotations.get(akey) != aval:
                    raise SystemExit(f"ERROR: {kind}/{name} is missing/has incorrect {akey} in {path}")
            continue
        metadata.setdefault("labels", {})[LABEL_KEY] = "true"
        annotations = metadata.setdefault("annotations", {})
        annotations[DISPLAY_KEY] = meta.display
        annotations[CATEGORY_KEY] = meta.category
        annotations[DESCRIPTION_KEY] = meta.description
        obj["metadata"] = metadata
    missing = set(targets) - seen
    if missing:
        rendered = ", ".join(f"{k}/{n}" for k, n in sorted(missing))
        raise SystemExit(f"ERROR: expected Platform Artifacts object(s) not found in {path}: {rendered}")
    if not check:
        path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")


def main() -> None:
    if len(sys.argv) not in (2, 3):
        raise SystemExit("usage: patch-custom-artifact-metadata.py <demo-repository-root> [--check]")
    root = Path(sys.argv[1]).resolve()
    check = len(sys.argv) == 3 and sys.argv[2] == "--check"
    if len(sys.argv) == 3 and not check:
        raise SystemExit(f"ERROR: unknown argument {sys.argv[2]}")
    if not (root / "demo.sh").exists():
        raise SystemExit(f"ERROR: {root} does not look like demo-openchoreo-deployment")

    for rel, targets in TARGETS.items():
        path = root / rel
        if not path.exists():
            raise SystemExit(f"ERROR: expected manifest not found: {path}")
        if path.suffix == ".json":
            patch_json_file(path, targets, check)
        else:
            patch_yaml_file(path, targets, check)

    action = "verified" if check else "embedded"
    count = sum(len(v) for v in TARGETS.values())
    print(f"Platform Artifacts ownership metadata {action} in source manifests: {count} objects")


if __name__ == "__main__":
    main()
