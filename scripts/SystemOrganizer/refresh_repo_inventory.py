#!/usr/bin/env python3
"""
Refresh System Organizer's repo inventory.

This is intentionally local-only and dependency-free. It scans configured roots
for Git repos and writes config/repo_inventory.json.
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parent.parent
ROOTS_FILE = REPO_ROOT / "config" / "repo_roots.json"
PROJECTS_FILE = REPO_ROOT / "config" / "projects.json"
INVENTORY_FILE = REPO_ROOT / "config" / "repo_inventory.json"


def load_json(path: Path, default: Any) -> Any:
    try:
      with path.open("r", encoding="utf-8") as f:
          return json.load(f)
    except FileNotFoundError:
      return default


def git_output(repo: Path, args: list[str]) -> str:
    try:
        result = subprocess.run(
            ["/usr/bin/git", "-C", str(repo), *args],
            check=False,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
        )
    except Exception:
        return ""
    if result.returncode != 0:
        return ""
    return result.stdout.strip()


def has_file(repo: Path, relative: str) -> bool:
    return (repo / relative).is_file()


def has_dir(repo: Path, relative: str) -> bool:
    return (repo / relative).is_dir()


def detect_languages(repo: Path) -> list[str]:
    languages: list[str] = []
    if has_file(repo, "Package.swift"):
        languages.append("swift")
    if has_file(repo, "package.json"):
        languages.append("node")
    if has_file(repo, "pyproject.toml") or has_file(repo, "requirements.txt") or has_file(repo, "manage.py"):
        languages.append("python")
    if any(repo.glob("*/manage.py")):
        languages.append("django")
    if has_file(repo, "Cargo.toml"):
        languages.append("rust")
    if has_file(repo, "go.mod"):
        languages.append("go")
    if has_file(repo, "README.md") and not languages:
        languages.append("docs")
    return languages


def detect_validation_hint(repo: Path) -> str:
    if has_file(repo, "scripts/validate.sh"):
        return "scripts/validate.sh"
    if has_file(repo, "Package.swift"):
        return "swift build"
    if has_file(repo, "Makefile"):
        return "make"
    if has_file(repo, "package.json"):
        return "npm run build"
    if has_file(repo, "manage.py"):
        return "python manage.py check"
    nested_manage = sorted(repo.glob("*/manage.py"))
    if nested_manage:
        nested_dir = nested_manage[0].parent.name
        return f"cd {nested_dir} && python manage.py check"
    return ""


def infer_group(name: str, path: Path, languages: list[str]) -> str:
    lower = name.lower()
    if lower.startswith("system_org"):
        return "core_system"
    if "fulofilo" in lower and "analytics" in lower:
        return "business_automation"
    if lower == "personallifeos":
        return "personal_system"
    if lower == "foks_bloomberg":
        return "local_app"
    if "skills" in lower:
        return "tooling"
    if "tensorflow" in lower or languages == ["docs"]:
        return "reference"
    if lower == "fulofilo_ff777":
        return "archive"
    return "reference"


def discover_repos(scan_roots: list[str], max_depth: int, ignore_names: set[str]) -> list[Path]:
    repos: list[Path] = []
    for root_text in scan_roots:
        root = Path(os.path.expanduser(os.path.expandvars(root_text))).resolve()
        if not root.is_dir():
            continue
        for current, dirs, _files in os.walk(root):
            current_path = Path(current)
            depth = len(current_path.relative_to(root).parts)
            if ".git" in dirs:
                repos.append(current_path)
                dirs[:] = []
                continue
            dirs[:] = [d for d in dirs if d not in ignore_names]
            if depth >= max_depth:
                dirs[:] = []
    return sorted(set(repos), key=lambda p: str(p).lower())


def main() -> int:
    roots_config = load_json(ROOTS_FILE, {})
    projects_config = load_json(PROJECTS_FILE, {"projects": []})
    scan_roots = roots_config.get("scan_roots") or [str(Path.home() / "Documents/GitHub")]
    max_depth = int(roots_config.get("max_depth") or 4)
    ignore_names = set(roots_config.get("ignore_names") or [])

    active_paths = {
        os.path.abspath(os.path.expanduser(os.path.expandvars(str(p.get("path")))))
        for p in projects_config.get("projects", [])
        if isinstance(p, dict) and p.get("path")
    }

    repos = []
    for repo in discover_repos(scan_roots, max_depth, ignore_names):
        name = repo.name
        languages = detect_languages(repo)
        branch = git_output(repo, ["rev-parse", "--abbrev-ref", "HEAD"]) or "unknown"
        dirty_count = len([line for line in git_output(repo, ["status", "--porcelain"]).splitlines() if line.strip()])
        group = infer_group(name, repo, languages)
        validation_hint = detect_validation_hint(repo)

        repos.append(
            {
                "name": name,
                "path": str(repo),
                "group": group,
                "status": "managed" if str(repo) in active_paths else group,
                "active_project": str(repo) in active_paths,
                "languages": languages,
                "validation_hint": validation_hint,
                "git": {
                    "branch": branch,
                    "dirty_count": dirty_count
                }
            }
        )

    inventory = {
        "version": 1,
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "scan_roots": scan_roots,
        "repos": repos
    }

    INVENTORY_FILE.parent.mkdir(parents=True, exist_ok=True)
    with INVENTORY_FILE.open("w", encoding="utf-8") as f:
        json.dump(inventory, f, indent=2)
        f.write("\n")

    print(f"Saved repo inventory: {INVENTORY_FILE}")
    print(f"Repos found: {len(repos)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
