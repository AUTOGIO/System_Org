#!/usr/bin/env python3
"""
Check health of all repos known to System Organizer.

The check is read-only. It does not fetch, pull, install dependencies, move
folders, or run project validation commands.
"""

from __future__ import annotations

import json
import os
import shlex
import subprocess
import sys
from pathlib import Path
from typing import Any


SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parent.parent
INVENTORY_FILE = REPO_ROOT / "config" / "repo_inventory.json"
PROJECTS_FILE = REPO_ROOT / "config" / "projects.json"

SEVERITY_ORDER = {
    "FAIL": 0,
    "WARN": 1,
    "INFO": 2,
    "OK": 3,
}


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


def command_hint_exists(repo: Path, command: str) -> bool:
    command = command.strip()
    if not command:
        return False
    try:
        parts = shlex.split(command)
    except ValueError:
        parts = command.split()
    if not parts:
        return False
    first = parts[0].strip("'\"")
    if first.startswith("/") or first.startswith("./") or "/" in first:
        return (repo / first).exists() if not first.startswith("/") else Path(first).exists()
    return True


def active_project_paths(projects: dict[str, Any]) -> set[str]:
    paths = set()
    for project in projects.get("projects", []):
        if isinstance(project, dict) and project.get("path"):
            paths.add(os.path.abspath(os.path.expanduser(str(project["path"]))))
    return paths


def project_by_path(projects: dict[str, Any]) -> dict[str, dict[str, Any]]:
    result = {}
    for project in projects.get("projects", []):
        if isinstance(project, dict) and project.get("path"):
            path = os.path.abspath(os.path.expanduser(str(project["path"])))
            result[path] = project
    return result


def git_health(repo_path: Path) -> dict[str, Any]:
    health: dict[str, Any] = {
        "branch": "unknown",
        "dirty_count": 0,
        "has_remote": False,
        "upstream": "",
        "ahead": 0,
        "behind": 0,
        "is_git": False,
    }

    if not (repo_path / ".git").exists():
        return health

    health["is_git"] = True
    code, branch = git_output(repo_path, ["rev-parse", "--abbrev-ref", "HEAD"])
    if code == 0 and branch:
        health["branch"] = branch

    code, status = git_output(repo_path, ["status", "--porcelain"])
    if code == 0:
        health["dirty_count"] = len([line for line in status.splitlines() if line.strip()])

    code, remotes = git_output(repo_path, ["remote"])
    if code == 0:
        health["has_remote"] = bool([line for line in remotes.splitlines() if line.strip()])

    code, upstream = git_output(repo_path, ["rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{upstream}"])
    if code == 0:
        health["upstream"] = upstream
        code, counts = git_output(repo_path, ["rev-list", "--left-right", "--count", "HEAD...@{upstream}"])
        if code == 0 and counts:
            parts = counts.split()
            if len(parts) == 2:
                health["ahead"] = int(parts[0])
                health["behind"] = int(parts[1])

    return health


def add(finding: list[dict[str, str]], severity: str, repo: str, message: str) -> None:
    finding.append({"severity": severity, "repo": repo, "message": message})


def check_repo(repo: dict[str, Any], projects_by_path: dict[str, dict[str, Any]]) -> list[dict[str, str]]:
    findings: list[dict[str, str]] = []
    name = str(repo.get("name") or "unknown")
    path = Path(os.path.expanduser(str(repo.get("path") or "")))
    abs_path = os.path.abspath(str(path))
    active = bool(repo.get("active_project"))
    group = str(repo.get("group") or "unknown")
    validation_hint = str(repo.get("validation_hint") or "")
    project = projects_by_path.get(abs_path, {})
    validate_cmd = str(project.get("validate_cmd") or "").strip()

    if not path.is_dir():
        add(findings, "FAIL", name, f"missing repo path: {path}")
        return findings

    gh = git_health(path)
    if not gh["is_git"]:
        add(findings, "FAIL", name, "path exists but is not a Git repo")
    else:
        if gh["dirty_count"]:
            add(findings, "WARN", name, f"working tree has {gh['dirty_count']} changed file(s)")
        if not gh["has_remote"]:
            add(findings, "WARN", name, "no Git remote configured")
        if gh["has_remote"] and not gh["upstream"]:
            add(findings, "INFO", name, f"branch {gh['branch']} has no upstream tracking branch")
        if gh["ahead"]:
            add(findings, "WARN", name, f"branch is ahead of upstream by {gh['ahead']} commit(s)")
        if gh["behind"]:
            add(findings, "WARN", name, f"branch is behind upstream by {gh['behind']} commit(s)")

    if active:
        if not validate_cmd:
            add(findings, "FAIL", name, "active project has no validate_cmd in projects.json")
        elif not command_hint_exists(path, validate_cmd):
            add(findings, "FAIL", name, f"validate_cmd points to missing script/path: {validate_cmd}")
        else:
            add(findings, "OK", name, f"active validation configured: {validate_cmd}")
    else:
        if group in {"reference", "archive"} and not validation_hint:
            add(findings, "OK", name, f"inventory-only {group} repo")
        elif validation_hint:
            add(findings, "INFO", name, f"inventory-only repo has possible check: {validation_hint}")
        else:
            add(findings, "INFO", name, f"inventory-only repo in group: {group}")

    if not findings:
        add(findings, "OK", name, "no issues found")
    return findings


def print_findings(findings: list[dict[str, str]]) -> None:
    grouped: dict[str, list[dict[str, str]]] = {"FAIL": [], "WARN": [], "INFO": [], "OK": []}
    for finding in findings:
        grouped.setdefault(finding["severity"], []).append(finding)

    print("Repo Health Check")
    print()
    for severity in ["FAIL", "WARN", "INFO", "OK"]:
        items = grouped.get(severity, [])
        if not items:
            continue
        print(f"== {severity} ==")
        for item in sorted(items, key=lambda x: (x["repo"].lower(), x["message"].lower())):
            print(f"- {item['repo']}: {item['message']}")
        print()

    fail_count = len(grouped["FAIL"])
    warn_count = len(grouped["WARN"])
    info_count = len(grouped["INFO"])
    ok_count = len(grouped["OK"])
    print(f"Summary: {fail_count} fail, {warn_count} warn, {info_count} info, {ok_count} ok")


def main() -> int:
    if not INVENTORY_FILE.exists():
        print(f"Missing inventory: {INVENTORY_FILE}", file=sys.stderr)
        print("Run refresh_repo_inventory.sh first.", file=sys.stderr)
        return 2

    inventory = load_json(INVENTORY_FILE)
    projects = load_json(PROJECTS_FILE)
    projects_by_path = project_by_path(projects)
    active_paths = active_project_paths(projects)

    findings: list[dict[str, str]] = []
    inventory_paths = set()
    for repo in inventory.get("repos", []):
        if not isinstance(repo, dict):
            continue
        path = os.path.abspath(os.path.expanduser(str(repo.get("path") or "")))
        inventory_paths.add(path)
        findings.extend(check_repo(repo, projects_by_path))

    for path in sorted(active_paths - inventory_paths):
        project = projects_by_path.get(path, {})
        name = str(project.get("name") or path)
        add(findings, "FAIL", name, f"active project is not present in repo inventory: {path}")

    findings.sort(key=lambda f: (SEVERITY_ORDER.get(f["severity"], 99), f["repo"].lower(), f["message"].lower()))
    print_findings(findings)
    return 1 if any(f["severity"] == "FAIL" for f in findings) else 0


if __name__ == "__main__":
    raise SystemExit(main())
