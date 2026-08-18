#!/usr/bin/env python3
from __future__ import annotations
import re
import sys
from pathlib import Path

if len(sys.argv) != 2:
    raise SystemExit("usage: patch-openchoreo-dockerfile.py <Dockerfile>")

path = Path(sys.argv[1]).resolve()
if not path.exists():
    raise SystemExit(f"ERROR: {path} does not exist")

text = path.read_text()
updated, count = re.subn(
    r"^FROM\s+--platform=linux/amd64\s+(node:22-bookworm-slim(?:\s+AS\s+\w+)?)\s*$",
    r"FROM \1",
    text,
    flags=re.MULTILINE,
)

if count == 0 and "--platform=linux/amd64" in text:
    raise SystemExit(
        "ERROR: OpenChoreo Dockerfile still contains a hard-coded linux/amd64 platform "
        "but its structure no longer matches the supported patch"
    )

if "--platform=linux/amd64" in updated:
    raise SystemExit("ERROR: hard-coded linux/amd64 remains in the patched Dockerfile")

path.write_text(updated)
print(f"Architecture patch applied to {path} ({count} FROM line(s) updated).")
