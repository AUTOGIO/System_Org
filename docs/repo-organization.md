# Repo Organization

System Organizer separates repo visibility from repo automation.

## Files

- `config/repo_roots.json`: folders that System Organizer scans for Git repos.
- `config/repo_inventory.json`: generated list of every repo found on disk.
- `config/repo_groups.json`: plain-English categories for repos.
- `config/projects.json`: active managed projects with safe validation commands.

## Operating Rule

Inventory everything. Manage only what matters. Automate only what is safe.

## Daily Commands

Refresh the full repo inventory:

```zsh
`$HOME/Documents/GitHub`/System_Org\ 2/scripts/SystemOrganizer/refresh_repo_inventory.sh
```

Show a readable inventory report:

```zsh
`$HOME/Documents/GitHub`/System_Org\ 2/scripts/SystemOrganizer/repo_inventory_report.sh
```

Show the compact repo state table:

```zsh
`$HOME/Documents/GitHub`/System_Org\ 2/scripts/SystemOrganizer/repo_state_summary.sh
```

Check Git/repo health without running builds:

```zsh
`$HOME/Documents/GitHub`/System_Org\ 2/scripts/SystemOrganizer/repo_health_check.sh
```

Run active project validation:

```zsh
`$HOME/Documents/GitHub`/System_Org\ 2/scripts/SystemOrganizer/project_safe_validation.sh
```

Install/update the live System Organizer app automation entries:

```zsh
`$HOME/Documents/GitHub`/System_Org\ 2/scripts/SystemOrganizer/configure_system_organizer.sh
```

This creates a timestamped backup of:

```text
~/Library/Application Support/SystemOrganizer/automations.json
```

It then updates repo-management automations to point at this repo's current
`scripts/SystemOrganizer` directory.

Deploy the local macOS app:

```zsh
`$HOME/Documents/GitHub`/System_Org\ 2/scripts/SystemOrganizer/deploy_system_organizer.sh
```

## Recommended Sequence

1. Refresh inventory.
2. Review the repo state summary.
3. Run repo health check.
4. Fix missing paths, broken validation entries, or repo classification issues.
5. Run active project validation.
6. Install/update the System Organizer app automation entries.
7. Promote inventory-only repos to `projects.json` only after their local checks are ready.

## Promotion Rule

A repo should enter `projects.json` only when System Organizer should actively
check it, report on it, or run a guarded daily command.

Reference and archive repos should stay in `repo_inventory.json` unless they
become active work.
