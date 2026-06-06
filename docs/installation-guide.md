# Installation Guide

## Target Machine

This project is configured for a personal Apple Silicon Mac.

```text
Target OS:     macOS 26.6
Architecture:  arm64
Install path:  /Applications/SystemOrganizer.app
Repo path:     /Users/giovannini_nuovo/Library/Mobile Documents/com~apple~CloudDocs/Documents/GitHub/System_Org 2
```

## Requirements

- Apple Silicon Mac, M3/M4 class.
- macOS 26.6.
- Xcode command-line tools or Xcode.
- Swift toolchain.
- Optional: Ollama for local AI.
- Optional: SSH keys for remote machine control.

## Verify Tooling

```zsh
sw_vers
uname -m
xcode-select --print-path
swift --version
```

## Install Or Update

Run:

```zsh
/Users/giovannini_nuovo/Library/Mobile Documents/com~apple~CloudDocs/Documents/GitHub/System_Org\ 2/scripts/SystemOrganizer/deploy_system_organizer.sh
```

The script builds, packages, backs up the previous app, installs the new app, updates live automations, launches the app, and verifies the process.

## Live App State

```text
~/Library/Application Support/SystemOrganizer/automations.json
~/Library/Application Support/SystemOrganizer/run_history.json
~/Library/Application Support/SystemOrganizer/remote_machines.json
~/Library/Application Support/SystemOrganizer/obsidian_vaults.json
```

The deploy/configuration scripts create timestamped backups before modifying the live automation file.

## Validate

```zsh
/Users/giovannini_nuovo/Library/Mobile Documents/com~apple~CloudDocs/Documents/GitHub/System_Org\ 2/scripts/SystemOrganizer/repo_health_check.sh
/Users/giovannini_nuovo/Library/Mobile Documents/com~apple~CloudDocs/Documents/GitHub/System_Org\ 2/scripts/SystemOrganizer/project_safe_validation.sh
```
