# Project Integration Guide

System Organizer manages local repos through a two-layer model.

```text
repo_inventory.json = all repos discovered on disk
projects.json       = active managed projects with safe validation commands
```

## Canonical Files

```text
/Users/giovannini_nuovo/Library/Mobile Documents/com~apple~CloudDocs/Documents/GitHub/System_Org 2/config/repo_roots.json
/Users/giovannini_nuovo/Library/Mobile Documents/com~apple~CloudDocs/Documents/GitHub/System_Org 2/config/repo_inventory.json
/Users/giovannini_nuovo/Library/Mobile Documents/com~apple~CloudDocs/Documents/GitHub/System_Org 2/config/repo_groups.json
/Users/giovannini_nuovo/Library/Mobile Documents/com~apple~CloudDocs/Documents/GitHub/System_Org 2/config/projects.json
```

## Active Managed Projects

| Project | Role | Safe Validation |
|---|---|---|
| System Organizer | Core system | `swift build` |
| FOKS Bloomberg | Local app | `scripts/validate.sh` |
| fulofilo-analytics | Business automation | `make automation-validate-data-integrity` |
| PersonalLifeOS | Personal system | `personallifeos_django_check.sh` |

## Inventory-Only Repos

| Repo | Reason |
|---|---|
| claude-skills-os | Tooling; possible check exists but it is not active managed yet |
| FuloFilo_FF777 | Reference/archive candidate |
| Initializing-TensorFlow-Environment-on-M3-M3-Pro-and-M3-Max-Macbook-Pros. | Reference |

## Repo Commands

Refresh all discovered repos:

```zsh
/Users/giovannini_nuovo/Library/Mobile Documents/com~apple~CloudDocs/Documents/GitHub/System_Org\ 2/scripts/SystemOrganizer/refresh_repo_inventory.sh
```

Show grouped inventory:

```zsh
/Users/giovannini_nuovo/Library/Mobile Documents/com~apple~CloudDocs/Documents/GitHub/System_Org\ 2/scripts/SystemOrganizer/repo_inventory_report.sh
```

Show compact operational state:

```zsh
/Users/giovannini_nuovo/Library/Mobile Documents/com~apple~CloudDocs/Documents/GitHub/System_Org\ 2/scripts/SystemOrganizer/repo_state_summary.sh
```

Run read-only repo health:

```zsh
/Users/giovannini_nuovo/Library/Mobile Documents/com~apple~CloudDocs/Documents/GitHub/System_Org\ 2/scripts/SystemOrganizer/repo_health_check.sh
```

Run active project validation:

```zsh
/Users/giovannini_nuovo/Library/Mobile Documents/com~apple~CloudDocs/Documents/GitHub/System_Org\ 2/scripts/SystemOrganizer/project_safe_validation.sh
```

## App Automations

These are installed into the live System Organizer app configuration:

```text
repo_refresh_inventory
repo_inventory_report
repo_state_summary
repo_state_summary_obsidian
repo_health_check
repo_health_check_obsidian
project_safe_validation
project_safe_validation_obsidian
```

## Promotion Rule

Promote a repo into `projects.json` only when:

- it is actively used;
- it has a safe validation command;
- its path is stable;
- the command does not mutate data unless explicitly guarded.

Do not physically move repos until absolute path references have been audited.
