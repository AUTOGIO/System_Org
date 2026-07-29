# Project Summary

System Organizer is a local-first macOS automation and repo-operations hub built with SwiftUI and SwiftPM.

## Implemented

- Native SwiftUI app and menu bar entry.
- Automation manager with JSON persistence, schedules, file watchers, chaining, run history, and notifications.
- Repo inventory scanner for ``$HOME/Documents/GitHub``.
- Repo state summary table.
- Repo health check with read-only Git and validation-configuration findings.
- Active project validation from `config/projects.json`.
- Obsidian report writers for repo state and repo health.
- Live app automation installer with backup of `~/Library/Application Support/SystemOrganizer/automations.json`.
- One-command local deploy to `/Applications/SystemOrganizer.app`.
- Local Ollama integration.
- EventKit Calendar view.
- SSH remote-machine persistence and command execution.
- XCTest coverage for script execution behavior.

## Active Managed Repos

```text
System_Org 2
FOKS_BLOOMBERG
fulofilo-analytics
PersonalLifeOS
```

## Inventory-Only Repos

```text
claude-skills-os
FuloFilo_FF777
Initializing-TensorFlow-Environment-on-M3-M3-Pro-and-M3-Max-Macbook-Pros.
```

## Canonical Commands

```zsh
swift build
swift test
zsh -n scripts/SystemOrganizer/*.sh
scripts/SystemOrganizer/repo_state_summary.sh
scripts/SystemOrganizer/repo_health_check.sh
scripts/SystemOrganizer/project_safe_validation.sh
```

## Current Non-Goals

- Cloud sync.
- Commercial deployment.
- Multi-user infrastructure.
- Physical repo moves before path-risk review.
- Unguarded mutating project automation.
