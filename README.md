# System Organizer

System Organizer is a personal, local-first macOS automation hub for Apple Silicon Macs. It is built with SwiftUI and SwiftPM, runs on this workstation, and manages local scripts, repo health, Obsidian reports, Git status, local Ollama access, Calendar, and SSH helpers.

This is not a team or commercial product. The target environment is this Mac: Apple Silicon M3/M4 class hardware on macOS 26.6.

## Current Deployment

```text
Installed app: /Applications/SystemOrganizer.app
Repo:          /Users/giovannini_nuovo/Library/Mobile Documents/com~apple~CloudDocs/Documents/GitHub/System_Org 2
Scripts:       /Users/giovannini_nuovo/Library/Mobile Documents/com~apple~CloudDocs/Documents/GitHub/System_Org 2/scripts/SystemOrganizer
App state:     ~/Library/Application Support/SystemOrganizer
Obsidian:      ~/Documents/OBSIDIAN_VAULTS/System Organizer/Reports
```

The deployed app has been built as an arm64 release binary, packaged as a macOS `.app`, ad-hoc signed for local use, installed under `/Applications`, launched, and verified running.

## Current Modules

| Module | Status | Notes |
|---|---|---|
| Automations | Working | Manual scripts, schedules, file watchers, chaining, run history, notifications |
| Repo Inventory | Working | Scans configured roots and writes `config/repo_inventory.json` |
| Repo State Summary | Working | Compact table of repo group, active status, branch, dirty count, upstream, and validation readiness |
| Repo Health Check | Working | Read-only findings for repo paths, Git state, upstream state, and validation configuration |
| Active Project Validation | Working | Runs safe validation commands from `config/projects.json` |
| Dashboard | Working | Automation, system, Git, and runtime status |
| Menu Bar | Working | Quick access to enabled automations |
| Obsidian | Working | Writes dated operational reports |
| AI Assistant | Working when Ollama is running | Uses local Ollama at `http://localhost:11434` |
| Calendar | Working with permission | EventKit day view |
| Remote Control | Working with SSH setup | Persisted machines and remote commands |

## Repo Model

System Organizer separates visibility from automation:

```text
config/repo_roots.json       folders to scan
config/repo_inventory.json   all discovered repos
config/repo_groups.json      repo categories
config/projects.json         active managed projects only
```

Current active managed repos:

```text
System_Org 2
FOKS_BLOOMBERG
fulofilo-analytics
PersonalLifeOS
```

Current inventory-only repos:

```text
claude-skills-os
FuloFilo_FF777
Initializing-TensorFlow-Environment-on-M3-M3-Pro-and-M3-Max-Macbook-Pros.
```

## Daily Commands

```zsh
/Users/giovannini_nuovo/Library/Mobile Documents/com~apple~CloudDocs/Documents/GitHub/System_Org\ 2/scripts/SystemOrganizer/repo_state_summary.sh
```

```zsh
/Users/giovannini_nuovo/Library/Mobile Documents/com~apple~CloudDocs/Documents/GitHub/System_Org\ 2/scripts/SystemOrganizer/repo_health_check.sh
```

```zsh
/Users/giovannini_nuovo/Library/Mobile Documents/com~apple~CloudDocs/Documents/GitHub/System_Org\ 2/scripts/SystemOrganizer/project_safe_validation.sh
```

## Deploy

Run the real local deployment:

```zsh
/Users/giovannini_nuovo/Library/Mobile Documents/com~apple~CloudDocs/Documents/GitHub/System_Org\ 2/scripts/SystemOrganizer/deploy_system_organizer.sh
```

The deploy script:

- verifies macOS and Apple Silicon architecture
- runs Swift tests
- builds the arm64 release binary
- packages `/Applications/SystemOrganizer.app`
- backs up any existing installed app
- signs the app locally
- installs live automation configuration
- launches and verifies the app

## Validation

Current verified checks:

```text
swift build                         passed
swift test                          passed
zsh -n scripts/SystemOrganizer/*.sh passed
repo_health_check.sh                0 fail
project_safe_validation.sh          passed all active projects
```

Expected current warnings are dirty working trees in active repos. They are real local work state, not deployment failures.

## Operating Rule

Inventory everything. Manage only what matters. Automate only what is safe.
