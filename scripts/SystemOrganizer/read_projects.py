#!/usr/bin/env python3
"""
Read System Organizer integration manifest and output projects.

Output format (one project per line, tab-separated):
  id<TAB>name<TAB>path<TAB>validate_cmd<TAB>daily_cmd<TAB>daily_requires_env<TAB>tags_csv

This script is intentionally tiny and dependency-free (stdlib only).
"""

from __future__ import annotations

import json
import os
import sys
from typing import Any, Dict, List


def _eprint(msg: str) -> None:
    print(msg, file=sys.stderr)


def _as_str(value: Any) -> str:
    if value is None:
        return ""
    if isinstance(value, str):
        return value
    return str(value)


def main() -> int:
    repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
    manifest = os.environ.get("SYSORG_PROJECTS_MANIFEST", os.path.join(repo_root, "config", "projects.json"))
    manifest = os.path.expanduser(manifest)

    try:
        with open(manifest, "r", encoding="utf-8") as f:
            data: Dict[str, Any] = json.load(f)
    except FileNotFoundError:
        _eprint(f"ERROR: projects manifest not found: {manifest}")
        return 2
    except Exception as e:
        _eprint(f"ERROR: could not read projects manifest: {manifest}: {e}")
        return 2

    if data.get("version") != 1:
        _eprint(f"ERROR: unsupported manifest version: {data.get('version')!r} (expected 1)")
        return 2

    projects = data.get("projects")
    if not isinstance(projects, list):
        _eprint("ERROR: manifest 'projects' must be a list")
        return 2

    for p in projects:
        if not isinstance(p, dict):
            continue

        pid = _as_str(p.get("id")).strip()
        name = _as_str(p.get("name")).strip() or pid
        path = os.path.expanduser(_as_str(p.get("path")).strip())
        validate_cmd = _as_str(p.get("validate_cmd")).strip()
        daily_cmd = _as_str(p.get("daily_cmd")).strip()
        daily_requires_env = _as_str(p.get("daily_requires_env")).strip()
        tags = p.get("tags") or []
        tags_csv = ",".join([_as_str(t).strip() for t in tags if _as_str(t).strip()]) if isinstance(tags, list) else ""

        if not pid or not path:
            continue

        print("\t".join([pid, name, path, validate_cmd, daily_cmd, daily_requires_env, tags_csv]))

    return 0


if __name__ == "__main__":
    raise SystemExit(main())

