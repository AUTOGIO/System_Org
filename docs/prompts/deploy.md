# System Organizer Deploy

System Organizer is deployed locally with one real command.

```zsh
`$HOME/Documents/GitHub`/System_Org\ 2/scripts/SystemOrganizer/deploy_system_organizer.sh
```

## What The Deploy Script Does

- verifies the host is Apple Silicon;
- reports the macOS version;
- runs the Swift test suite;
- builds the release binary for arm64;
- creates `/Applications/SystemOrganizer.app`;
- backs up the previous installed app under `dist/deploy-backups`;
- ad-hoc signs the app for local macOS use;
- installs or updates live System Organizer automations;
- launches the app;
- verifies the running `SystemOrganizer` process;
- prints the repo health report.

## Current Target

```text
Target OS:     macOS 13+ (Package.swift); deploy Info.plist currently 26.0
Architecture:  arm64
Install path:  /Applications/SystemOrganizer.app
Repo path:     `$HOME/Documents/GitHub/System_Org 2` (or this clone)
```

## Post-Deploy Checks

```zsh
codesign --verify --deep --strict /Applications/SystemOrganizer.app
plutil -lint /Applications/SystemOrganizer.app/Contents/Info.plist
file /Applications/SystemOrganizer.app/Contents/MacOS/SystemOrganizer
pgrep -x SystemOrganizer
```

## Operational Checks

```zsh
`$HOME/Documents/GitHub`/System_Org\ 2/scripts/SystemOrganizer/repo_state_summary.sh
`$HOME/Documents/GitHub`/System_Org\ 2/scripts/SystemOrganizer/repo_health_check.sh
`$HOME/Documents/GitHub`/System_Org\ 2/scripts/SystemOrganizer/project_safe_validation.sh
```
