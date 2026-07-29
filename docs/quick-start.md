# Quick Start

## Use The Deployed App

```zsh
open /Applications/SystemOrganizer.app
```

Verify it is running:

```zsh
pgrep -x SystemOrganizer
```

## Daily Repo Checks

```zsh
`$HOME/Documents/GitHub`/System_Org\ 2/scripts/SystemOrganizer/repo_state_summary.sh
```

```zsh
`$HOME/Documents/GitHub`/System_Org\ 2/scripts/SystemOrganizer/repo_health_check.sh
```

```zsh
`$HOME/Documents/GitHub`/System_Org\ 2/scripts/SystemOrganizer/project_safe_validation.sh
```

## App Automations

Open:

```text
System Organizer -> Automations
```

Useful manual automations:

```text
Repo Refresh Inventory
Repo Inventory Report
Repo State Summary
Repo State Summary (Obsidian)
Repo Health Check
Repo Health Check (Obsidian)
Project Safe Validation
Project Safe Validation (Obsidian)
```

## Re-Deploy

```zsh
`$HOME/Documents/GitHub`/System_Org\ 2/scripts/SystemOrganizer/deploy_system_organizer.sh
```

## Optional Local Services

- Ollama should be running for the AI tab.
- SSH keys must exist before using Remote commands.
- Calendar permissions must be granted before Calendar data appears.
