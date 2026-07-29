#!/usr/bin/env python3
"""
Print a compact state table for all repos in System Organizer inventory.

Read-only by design. This script does not fetch, build, install, move, or clean.
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path
from typing import Any


SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parent.parent
INVENTORY_FILE = REPO_ROOT / "config" / "repo_inventory.json"
PROJECTS_FILE = REPO_ROOT / "config" / "projects.json"


def load_json(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as f:
        data = json.load(f)
    if not isinstance(data, dict):
        raise ValueError(f"Expected JSON object: {path}")
    return data


def git_output(repo: Path, args: list[str]) -> tuple[int, str]:
    try:
        result = subprocess.run(
            ["/usr/bin/git", "-C", str(repo), *args],
            check=False,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
    except Exception as exc:
        return 1, str(exc)
    output = result.stdout.strip() or result.stderr.strip()
    return result.returncode, output


def projects_by_path(projects: dict[str, Any]) -> dict[str, dict[str, Any]]:
    result: dict[str, dict[str, Any]] = {}
    for project in projects.get("projects", []):
        if isinstance(project, dict) and project.get("path"):
            path = os.path.abspath(os.path.expanduser(os.path.expandvars(str(project["path"]))))
            result[path] = project
    return result


def git_state(path: Path) -> dict[str, Any]:
    state: dict[str, Any] = {
        "exists": path.is_dir(),
        "git": (path / ".git").exists(),
        "branch": "-",
        "dirty": "-",
        "remote": "no",
        "upstream": "none",
        "ahead": 0,
        "behind": 0,
    }
    if not state["exists"] or not state["git"]:
        return state

    code, branch = git_output(path, ["rev-parse", "--abbrev-ref", "HEAD"])
    if code == 0 and branch:
        state["branch"] = branch

    code, status = git_output(path, ["status", "--porcelain"])
    if code == 0:
        state["dirty"] = str(len([line for line in status.splitlines() if line.strip()]))

    code, remotes = git_output(path, ["remote"])
    if code == 0 and any(line.strip() for line in remotes.splitlines()):
        state["remote"] = "yes"

    code, upstream = git_output(path, ["rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{upstream}"])
    if code == 0 and upstream:
        state["upstream"] = upstream
        code, counts = git_output(path, ["rev-list", "--left-right", "--count", "HEAD...@{upstream}"])
        if code == 0 and counts:
            parts = counts.split()
            if len(parts) == 2:
                state["ahead"] = int(parts[0])
                state["behind"] = int(parts[1])
    return state


def validation_label(repo: dict[str, Any], project: dict[str, Any] | None) -> str:
    if project:
        cmd = str(project.get("validate_cmd") or "").strip()
        return "configured" if cmd else "missing"
    hint = str(repo.get("validation_hint") or "").strip()
    return "hint" if hint else "none"


def shorten(value: str, width: int) -> str:
    if len(value) <= width:
        return value
    if width <= 1:
        return value[:width]
    return value[: width - 1] + "…"


def print_table(rows: list[dict[str, str]]) -> None:
    columns = [
        ("repo", 34),
        ("group", 19),
        ("active", 6),
        ("branch", 34),
        ("dirty", 5),
        ("remote", 6),
        ("upstream", 28),
        ("sync", 9),
        ("check", 10),
    ]
    header = "  ".join(label.ljust(width) for label, width in columns)
    rule = "  ".join("-" * width for _label, width in columns)
    print(header)
    print(rule)
    for row in rows:
        print("  ".join(shorten(row.get(label, ""), width).ljust(width) for label, width in columns))


def main() -> int:
    if not INVENTORY_FILE.exists():
        print(f"Missing inventory: {INVENTORY_FILE}", file=sys.stderr)
        print("Run refresh_repo_inventory.sh first.", file=sys.stderr)
        return 2

    inventory = load_json(INVENTORY_FILE)
    projects = load_json(PROJECTS_FILE)
    project_map = projects_by_path(projects)
    rows: list[dict[str, str]] = []

    for repo in inventory.get("repos", []):
        if not isinstance(repo, dict):
            continue
        path = Path(os.path.expanduser(os.path.expandvars(str(repo.get("path") or ""))))
        abs_path = os.path.abspath(str(path))
        project = project_map.get(abs_path)
        state = git_state(path)
        ahead = int(state.get("ahead") or 0)
        behind = int(state.get("behind") or 0)
        sync = "clean"
        if ahead or behind:
            sync = f"+{ahead}/-{behind}"
        if not state["exists"]:
            sync = "missing"
        elif not state["git"]:
            sync = "not-git"

        rows.append(
            {
                "repo": str(repo.get("name") or path.name),
                "group": str(repo.get("group") or "unknown"),
                "active": "yes" if project else "no",
                "branch": str(state["branch"]),
                "dirty": str(state["dirty"]),
                "remote": str(state["remote"]),
                "upstream": str(state["upstream"]),
                "sync": sync,
                "check": validation_label(repo, project),
            }
        )

    rows.sort(key=lambda r: (r["active"] != "yes", r["group"], r["repo"].lower()))
    print("Repo State Summary")
    print(f"Generated: {inventory.get('generated_at', 'unknown')}")
    print()
    print_table(rows)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
