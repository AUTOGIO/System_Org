#!/usr/bin/env python3
"""
Install System Organizer repo-management configuration.

This script is local-only and conservative:
- validates repo-management JSON files
- ensures repo scripts are executable
- refreshes repo inventory
- backs up live app automations.json
- upserts repo-management automations into the live app config
- rewrites stale SystemOrganizer script paths when the target script exists
"""

from __future__ import annotations

import json
import os
import shutil
import stat
import subprocess
import sys
from datetime import datetime
from pathlib import Path
from typing import Any


SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parent.parent
CONFIG_DIR = REPO_ROOT / "config"
APP_SUPPORT = Path.home() / "Library" / "Application Support" / "SystemOrganizer"
AUTOMATIONS_FILE = APP_SUPPORT / "automations.json"
SCRIPTS_ROOT = str(SCRIPT_DIR)
OLD_SCRIPT_ROOTS = [
    str(Path.home() / "Documents/Active_Projects/System_Org/scripts/SystemOrganizer"),
    str(Path.home() / "Documents/GitHub/System_Org/scripts/SystemOrganizer"),
]


def run(cmd: list[str], cwd: Path | None = None) -> None:
    result = subprocess.run(cmd, cwd=str(cwd) if cwd else None, text=True)
    if result.returncode != 0:
        raise RuntimeError(f"Command failed with {result.returncode}: {' '.join(cmd)}")


def load_json(path: Path, default: Any) -> Any:
    if not path.exists():
        return default
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def save_json(path: Path, data: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    with tmp.open("w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)
        f.write("\n")
    tmp.replace(path)


def validate_json_files() -> None:
    for name in ["projects.json", "repo_roots.json", "repo_groups.json"]:
        path = CONFIG_DIR / name
        if not path.exists():
            raise FileNotFoundError(f"Missing required config file: {path}")
        load_json(path, {})


def ensure_executable_scripts() -> None:
    for path in SCRIPT_DIR.glob("*.sh"):
        mode = path.stat().st_mode
        path.chmod(mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)
    for path in SCRIPT_DIR.glob("*.py"):
        mode = path.stat().st_mode
        path.chmod(mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)


def automation(
    id: str,
    name: str,
    description: str,
    script: str,
    tags: list[str],
    notes: str = "Installed by System Organizer repo-management configuration.",
) -> dict[str, Any]:
    return {
        "id": id,
        "name": name,
        "description": description,
        "isEnabled": False,
        "scriptPath": f"{SCRIPTS_ROOT}/{script}",
        "scriptContent": "",
        "schedule": "manual",
        "lastRun": None,
        "category": "Development",
        "tags": tags,
        "notes": notes,
        "dependsOn": [],
        "triggersOnSuccess": [],
    }


def repo_automations() -> list[dict[str, Any]]:
    return [
        automation(
            "repo_refresh_inventory",
            "Repo Refresh Inventory",
            "Refresh the full local Git repo inventory.",
            "refresh_repo_inventory.sh",
            ["repos", "inventory"],
        ),
        automation(
            "repo_inventory_report",
            "Repo Inventory Report",
            "Show discovered repos grouped by operational category.",
            "repo_inventory_report.sh",
            ["repos", "inventory", "report"],
        ),
        automation(
            "repo_state_summary",
            "Repo State Summary",
            "Show a compact table of repo group, branch, dirty state, upstream, and validation readiness.",
            "repo_state_summary.sh",
            ["repos", "git", "summary"],
        ),
        automation(
            "repo_state_summary_obsidian",
            "Repo State Summary (Obsidian)",
            "Write the repo state summary to the configured Obsidian vault.",
            "repo_state_summary_obsidian.sh",
            ["repos", "git", "summary", "obsidian"],
        ),
        automation(
            "repo_health_check",
            "Repo Health Check",
            "Check repo paths, Git state, upstream status, and active validation configuration without running builds.",
            "repo_health_check.sh",
            ["repos", "git", "health"],
        ),
        automation(
            "repo_health_check_obsidian",
            "Repo Health Check (Obsidian)",
            "Write the repo health check to the configured Obsidian vault.",
            "repo_health_check_obsidian.sh",
            ["repos", "git", "health", "obsidian"],
        ),
        automation(
            "project_safe_validation",
            "Project Safe Validation",
            "Run non-mutating validation/build checks across active managed projects.",
            "project_safe_validation.sh",
            ["projects", "validation", "safe"],
        ),
        automation(
            "project_safe_validation_obsidian",
            "Project Safe Validation (Obsidian)",
            "Run active project validation and write a dated Obsidian note.",
            "project_safe_validation_obsidian.sh",
            ["projects", "validation", "safe", "obsidian"],
        ),
    ]


def rewrite_stale_script_path(path: str) -> str:
    for old_root in OLD_SCRIPT_ROOTS:
        if path.startswith(old_root + "/"):
            script_name = path.rsplit("/", 1)[-1]
            candidate = SCRIPT_DIR / script_name
            if candidate.exists():
                return str(candidate)
    return path


def merge_automation(existing: dict[str, Any] | None, desired: dict[str, Any]) -> dict[str, Any]:
    if not existing:
        return desired
    merged = dict(existing)
    for key in ["name", "description", "scriptPath", "scriptContent", "category", "tags", "notes", "dependsOn", "triggersOnSuccess"]:
        merged[key] = desired[key]
    merged.setdefault("isEnabled", desired["isEnabled"])
    merged.setdefault("schedule", desired["schedule"])
    merged.setdefault("lastRun", desired["lastRun"])
    return merged


def backup_file(path: Path) -> Path | None:
    if not path.exists():
        return None
    stamp = datetime.now().strftime("%Y-%m-%dT%H-%M-%S")
    backup = path.with_name(f"{path.name}.bak-{stamp}")
    shutil.copy2(path, backup)
    return backup


def install_automations() -> tuple[Path | None, int]:
    automations = load_json(AUTOMATIONS_FILE, [])
    if not isinstance(automations, list):
        raise ValueError(f"Expected automation list: {AUTOMATIONS_FILE}")

    backup = backup_file(AUTOMATIONS_FILE)
    by_id = {str(item.get("id")): item for item in automations if isinstance(item, dict) and item.get("id")}

    updated: list[dict[str, Any]] = []
    seen: set[str] = set()
    desired_by_id = {item["id"]: item for item in repo_automations()}

    for item in automations:
        if not isinstance(item, dict):
            continue
        item = dict(item)
        if isinstance(item.get("scriptPath"), str):
            item["scriptPath"] = rewrite_stale_script_path(item["scriptPath"])
        item_id = str(item.get("id") or "")
        if item_id in desired_by_id:
            item = merge_automation(item, desired_by_id[item_id])
        updated.append(item)
        seen.add(item_id)

    for item_id, desired in desired_by_id.items():
        if item_id not in seen:
            updated.append(merge_automation(by_id.get(item_id), desired))

    save_json(AUTOMATIONS_FILE, updated)
    return backup, len(desired_by_id)


def main() -> int:
    validate_json_files()
    ensure_executable_scripts()
    run([str(SCRIPT_DIR / "refresh_repo_inventory.sh")], cwd=REPO_ROOT)
    backup, count = install_automations()
    print("System Organizer repo-management configuration installed.")
    print(f"Scripts root: {SCRIPTS_ROOT}")
    print(f"Automations installed/updated: {count}")
    if backup:
        print(f"Automation backup: {backup}")
    print(f"Live automations: {AUTOMATIONS_FILE}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise SystemExit(1)
