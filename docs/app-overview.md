# App Overview

System Organizer is a personal macOS SwiftUI app for local automation and repo operations on Apple Silicon.

## Purpose

The app is the control surface for local scripts, project health, repo state, Obsidian reporting, Calendar, SSH helpers, and local AI through Ollama. It is designed for this workstation, not for multi-user SaaS or cloud deployment.

## Runtime

```text
Installed app: /Applications/SystemOrganizer.app
Architecture:  arm64
Target OS:     macOS 13+ (Package.swift); deploy Info.plist currently 26.0
State folder:  ~/Library/Application Support/SystemOrganizer
Scripts root:  `$HOME/Documents/GitHub/System_Org 2` (or this clone)/scripts/SystemOrganizer
```

## Main Surfaces

- Dashboard: system, automation, Git, and runtime status.
- Automations: manual and scheduled local scripts.
- Repo operations: inventory, state summary, health check, active validation.
- Obsidian: dated operational reports in the configured vault.
- AI: local Ollama chat when Ollama is running.
- Calendar: local EventKit day view.
- Remote: SSH machine list and command execution.
- Settings: launch, notifications, Git scan paths, and retention settings.

## Repo Operations

The repo system is configuration-driven:

```text
repo_inventory.json = all discovered repos
projects.json       = active managed repos only
```

The most important commands are:

```zsh
scripts/SystemOrganizer/repo_state_summary.sh
scripts/SystemOrganizer/repo_health_check.sh
scripts/SystemOrganizer/project_safe_validation.sh
```

## Non-Goals

- No cloud-first sync.
- No Docker or Kubernetes.
- No fake data or mock deployment.
- No repo moving until path dependencies are audited.
- No mutating project automation unless explicitly guarded.
