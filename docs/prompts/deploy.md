# System Organizer Deploy

System Organizer is deployed locally with one real command.

```zsh
/Users/giovannini_nuovo/Library/Mobile Documents/com~apple~CloudDocs/Documents/GitHub/System_Org\ 2/scripts/SystemOrganizer/deploy_system_organizer.sh
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
Target OS:     macOS 26.6
Architecture:  arm64
Install path:  /Applications/SystemOrganizer.app
Repo path:     /Users/giovannini_nuovo/Library/Mobile Documents/com~apple~CloudDocs/Documents/GitHub/System_Org 2
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
/Users/giovannini_nuovo/Library/Mobile Documents/com~apple~CloudDocs/Documents/GitHub/System_Org\ 2/scripts/SystemOrganizer/repo_state_summary.sh
/Users/giovannini_nuovo/Library/Mobile Documents/com~apple~CloudDocs/Documents/GitHub/System_Org\ 2/scripts/SystemOrganizer/repo_health_check.sh
/Users/giovannini_nuovo/Library/Mobile Documents/com~apple~CloudDocs/Documents/GitHub/System_Org\ 2/scripts/SystemOrganizer/project_safe_validation.sh
```
