# Audit Remediation Upgrade Report

**Date:** 2026-07-29  
**Branch:** `fix/audit-remediation`  
**Source:** [REPOSITORY_AUDIT.md](../REPOSITORY_AUDIT.md)

## Verdict

System Organizer is buildable and testable again on this Mac. Hardcoded former-user paths are gone from executable configs/scripts. Live automations no longer schedule missing or destructive scripts. Deploy is portable from the clone root.

## What Changed

### Build & dependency (AUDIT-001, AUDIT-010)

- Cloned private sibling kit: `~/Documents/GitHub/PersonalOSKit`
- `Package.swift` now depends on `../PersonalOSKit` and only the `OllamaClient` product (dropped unused `ShellRunner`)
- README documents the PersonalOSKit prerequisite

### Path portability (AUDIT-002, AUDIT-011)

- Scripts and config use `$HOME` / repo-relative roots instead of `/Users/giovannini_nuovo/...`
- Deploy script: `PROJECT="$(cd "$(dirname "$0")/../.." && pwd)"`
- Deploy packages `assets/logo.png` when present
- Python helpers expand `$HOME` via `expandvars` + `expanduser`
- Regenerated `config/repo_inventory.json` against `$HOME/Documents/GitHub`

### Live automations (AUDIT-003, AUDIT-004)

- Backed up Application Support automations before edits
- Disabled entries whose scripts were missing (`$HOME/Documents/scripts/...`)
- Disabled destructive automations (desktop organize, downloads clean, evening shutdown, morning startup, guarded fulofilo)
- Desktop/downloads scripts support `DRY_RUN=1`
- Evening shutdown requires `CONFIRM_EVENING_SHUTDOWN=1`
- Fresh-install defaults set `organize_desktop` to `isEnabled: false`

### Reliability & correctness (AUDIT-005, AUDIT-006, AUDIT-013, AUDIT-014)

- Global ⌘⌥Space hotkey monitor is retained (`GlobalHotkeyMonitor`)
- `ProcessManager` enforces a 10-minute wall-clock timeout
- SSH remote commands require confirmation before run
- Deploy Info.plist includes `NSAccessibilityUsageDescription`

### Docs, tests, hygiene (AUDIT-007–009, AUDIT-012)

- Docs rewritten to repo-relative commands; OS claims aligned with Package.swift
- Tests expanded: timeout, `$HOME`/`~` expand, schedule fire dates, Codable round-trip (9 tests)
- Removed broken git ref `main 2`
- Stripped agent debug NDJSON logging from `scripts/git-push-clean.sh`

## Verification (this workstation)

| Check | Result |
|-------|--------|
| `swift test` | 9 tests, 0 failures |
| `rg giovannini_nuovo` (excl. audit report) | Clean |
| Enabled live automations with missing scripts | None |
| Deploy PROJECT resolution | Resolves to this clone |
| `../PersonalOSKit` present | Yes |

## Deploy status (this workstation)

- Installed: `/Applications/SystemOrganizer.app` v2.1.0
- Launched and verified running after deploy
- Accessibility usage string present in bundled Info.plist

## Round 3 (polish)

- Persistence failures surface as an in-app banner + notification
- Integrations refresh Obsidian/Remote tabs live (no relaunch)
- Obsidian Enable uses folder picker; Remote Enable uses Add Machine sheet
- Timer/`@MainActor` scheduling callbacks hop via `Task { @MainActor in … }`
- README documents `--scratch-path /tmp/SystemOrganizer-spm-build` for tests
- Pruned old `automations.json.bak-*` (kept 3 newest)

## Round 2 (full fix — agreed scope)

- All automation schedules forced to **manual**
- Missing-project wrappers **retired** (morning/finance stubs; dead App Support entries removed)
- Destructive runs require **in-app confirm**, then pass `CONFIRM_EVENING_SHUTDOWN` / `ALLOW_PROJECT_DATA_WRITES`
- Obsidian + Remote tabs **hidden** until Settings → Integrations → Enable
- Global hotkey **removed**
- Ship: PR → merge `main` → redeploy

## Remaining operator notes

1. **PersonalOSKit** must stay checked out as a sibling of this repo on every build machine.
2. After Enable for Obsidian/Remote in Settings, **relaunch** to show tabs.
3. Click through each **enabled** automation once in the UI (success criterion B).
4. Schedules are manual only — no LaunchAgent.

## Files touched (high level)

- `Package.swift`, `README.md`, `Sources/*`, `Tests/*`
- `config/projects.json`, `config/repo_roots.json`, `config/repo_inventory.json`
- `scripts/SystemOrganizer/*`, `scripts/git-push-clean.sh`
- `docs/*`
- Runtime: `~/Library/Application Support/SystemOrganizer/automations.json` (with backup)
