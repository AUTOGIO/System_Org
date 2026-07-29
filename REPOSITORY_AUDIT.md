# Repository Audit Report

## 1. Executive Summary

System Organizer is a personal, local-first macOS SwiftUI / SwiftPM automation hub: it runs local scripts, tracks Git/repo health, talks to Ollama, reads Calendar via EventKit, and can SSH to remote machines. An ad-hoc-signed `/Applications/SystemOrganizer.app` (v2.1.0, arm64) is installed but not currently running.

**The repository cannot currently build or test from source.** `Package.swift` depends on a filesystem package at `/Users/giovannini_nuovo/Developer/PersonalOSKit`, which does not exist on this machine. Across scripts, config, and docs, many paths still hardcode that former username, while the live workspace user is `eduardofgiovannini`. A prior commit claimed dynamic `$HOME` resolution; remediation is incomplete.

Highest-priority work: restore a buildable PersonalOSKit dependency (or vendor the used `OllamaClient` surface), replace remaining hardcoded absolute user paths with `$HOME`/`Path.home()`/`REPO_ROOT` resolution, and sanitize live Application Support automations that point at missing scripts or destructive routines.

**Do not begin broad feature work until build + path correctness are restored.**

## 2. Audit Scope and Limitations

- **Mode:** Read-only except creation of this report.
- **Completed:** Repository mapping; purpose/stack/architecture; source and script review; config/docs comparison; security pattern scan; dependency/test/docs/macOS/shell/hygiene review; safe toolchain and build checks.
- **Not executed (by design or safety):** `swift test` (blocked by missing dependency); deploy script; any mutating automation; package installs; credentialed remote calls.
- **Runtime state inspected (read-only):** Installed app bundle, Application Support JSON presence/paths (no secret values printed), process list for `SystemOrganizer`.
- **Assumption:** This is a single-operator personal workstation tool, not a multi-user or cloud service. Severity is calibrated accordingly (e.g. SSH remote exec is intentional local capability, not a SaaS auth hole).

## 3. Initial Repository State

| Item | Value |
|------|--------|
| Repository root | `/Users/eduardofgiovannini/Documents/GitHub/System_Org 2` |
| Current branch | `main` (tracks `origin/main`) |
| HEAD | `8df8575` — `chore: tidy repo layout into assets, docs, and archive` |
| Remote | `https://github.com/AUTOGIO/System_Org.git` |
| Submodules | None |
| Worktrees | Single worktree |
| Nested repos | None |
| Size | ~52M working tree; `.build` ~39M; `dist` ~10M (ignored) |
| Uncommitted changes | `M scripts/git-push-clean.sh` |
| Submodule status | N/A (no `.gitmodules`) |
| Notable local-only | `.build/`, `dist/`, `archive/SystemOrganizer.tar.gz` (gitignored), `__pycache__/` |
| Broken ref | `.git/refs/heads/main 2` (stale/orphan branch name with space) |
| Path alias | iCloud Documents path and `Documents/GitHub/...` are the **same directory** (`os.path.samefile` = true) |

## 4. Repository Purpose

### Documented behavior

- Personal macOS automation hub (README, `docs/app-overview.md`, `AGENTS.md`).
- Surfaces: Dashboard, Automations, AI (Ollama), Remote SSH, Calendar, Obsidian, Settings.
- Deploy via `scripts/SystemOrganizer/deploy_system_organizer.sh` to `/Applications/SystemOrganizer.app`.
- Config-driven repo inventory / portfolio validation under `config/`.

### Implemented behavior

- SwiftUI `@main` app (`Sources/SystemOrganizerApp.swift`) with MenuBarExtra, SMAppService launch-at-login, notifications, automation CRUD/schedule/file-watch/chains, Git scan UI, EventKit calendar, SSH helpers, Obsidian vault UI, Ollama chat via `OllamaClient`.
- Large set of zsh/Python helpers under `scripts/SystemOrganizer/` for sibling projects (finance, fulofilo, PersonalLifeOS, GMC placeholders, desktop/downloads cleanup, morning/evening routines).
- Persistence under `~/Library/Application Support/SystemOrganizer/` (`automations.json`, `run_history.json`, optional machines/vaults JSON).

### Inferred behavior

- Intended for one Apple Silicon Mac owned by the author; scripts orchestrate other personal repos that may or may not be present.
- “Deploy” means local ad-hoc codesign + copy to `/Applications`, not App Store or CI CD.

### Unresolved assumptions

- Where `PersonalOSKit` now lives (or whether it should be vendored / published).
- Whether `giovannini_nuovo` paths are obsolete after a username/machine migration, or intentionally dual-home.
- Whether live enabled automations that reference `$HOME/Documents/scripts/...` are intentional leftovers.

### Likely user / workflows

- Single power user: open app → run automations → review repo health → optional Obsidian notes / Ollama help / SSH.

### Inputs / outputs / persistence / services

| Kind | Evidence |
|------|----------|
| Inputs | Local script paths, UserDefaults, JSON config, SSH targets, Ollama prompts, Calendar |
| Outputs | Script stdout in UI/history, Obsidian notes, Desktop reports, moved Desktop/Downloads files |
| Persistent data | Application Support JSON; `config/*.json`; UserDefaults |
| External | Optional local Ollama (`localhost:11434`); optional SSH remotes; EventKit; Obsidian vault filesystem |
| Deploy model | Local `/Applications` ad-hoc signed app |

## 5. Repository Map

| Path | Purpose |
|------|---------|
| `Sources/` | SwiftUI app + managers (~16 Swift files) |
| `Tests/SystemOrganizerTests/` | XCTest: `ProcessManager` + path expand |
| `Package.swift` | SwiftPM 6.0 executable + tests; local PersonalOSKit dep |
| `scripts/SystemOrganizer/` | Deploy, configure, repo health, portfolio, project wrappers |
| `scripts/git-push-clean.sh` | One-shot interactive commit/push helper (debug logs) |
| `config/` | `projects.json`, `repo_roots.json`, `repo_groups.json`, `repo_inventory.json` |
| `docs/` | Guides, overview, deploy prompt |
| `docs/prompts/` | AI deploy prompt |
| `assets/` | `logo.png` |
| `archive/` | Obsolete pbxproj, docx backup, local tar.gz, Icon |
| `dist/` | Local deploy staging/backups (gitignored) |
| `.build/` | SwiftPM build cache (gitignored) |
| Root | `README.md`, `AGENTS.md`, workspace file |

No CI workflows, Docker, or cloud infra present.

## 6. Technology Stack

| Technology | Evidence |
|------------|----------|
| Swift 6 / SwiftPM | `Package.swift` (`swift-tools-version: 6.0`); host Swift 6.4 |
| SwiftUI + AppKit | Views; `NSEvent`, `NSApp` |
| ServiceManagement | `SMAppService` launch at login |
| EventKit | `CalendarView.swift` |
| UserNotifications | `NotificationManager.swift` |
| PersonalOSKit (local path) | `Package.swift` → `OllamaClient` (+ unused `ShellRunner`) |
| zsh / bash | Deploy and automation scripts |
| Python 3 | Inventory/configure/repo health helpers |
| XCTest | `Tests/SystemOrganizerTests/ProcessManagerTests.swift` |
| Git / SSH / osascript | Managers and shell scripts |
| Optional Ollama | `OllamaManager.swift`; deploy curl to `:11434` |
| Homebrew paths | `/opt/homebrew/bin/npm` in morning routine |
| Target OS | Package: macOS 13+; deploy Info.plist: 26.0; docs claim 26.6; host observed 27.0 |

No `Package.resolved` (path dependency). No CocoaPods/npm app lockfiles for the Swift app.

## 7. Architecture Overview

```text
┌─────────────────────────────────────────────────────────┐
│  SystemOrganizer.app (SwiftUI + MenuBarExtra)           │
│  Managers: Automation, Monitoring, Git, Ollama, Notify  │
└───────────────┬─────────────────────────────┬───────────┘
                │ Process / bash|python|osascript
                ▼                             ▼
     scripts/SystemOrganizer/*        Optional: Ollama, SSH, EventKit
                │
                ▼
     config/*.json  +  sibling project trees (hardcoded paths)
```

- **Boundary:** Thin native UI over local process execution; real business logic mostly lives in shell/Python.
- **Persistence:** Application Support JSON + UserDefaults; config manifests in-repo.
- **Ambition–Capacity Mismatch:** UI and docs describe a full personal OS control plane (morning/evening, finance, fulofilo guarded writes, GMC, portfolio health, Obsidian dual wrappers). Maintenance capacity and path portability do not match that surface: many wrappers target absences, GMC is already a no-op, and build is blocked by a missing private kit.
- Prefer **incremental path/build fixes** over rewriting into a framework platform.

## 8. Build, Test, and Run Procedure

### Canonical (documented)

1. Apple Silicon Mac + Xcode / CLT + Swift.
2. Optional: Ollama; SSH keys; Calendar/Accessibility permissions.
3. `swift build` / `swift test`.
4. Deploy: `scripts/SystemOrganizer/deploy_system_organizer.sh`.
5. Run: `open /Applications/SystemOrganizer.app`.

### Actual blockers on this machine

1. **PersonalOSKit path missing** → `swift build` / `swift test` / deploy all fail.
2. Deploy script sets `PROJECT="/Users/giovannini_nuovo/..."` → wrong on this user.
3. Many helper scripts hardcode the same former home directory.

### Stop / recover

- Quit app via UI or `osascript`/`pkill` (deploy script pattern).
- App Support backups created by configure script (`automations.json.bak-*`).
- Deploy keeps prior app under `dist/deploy-backups/` (local).

### Conflicts

- README says relative deploy path; most docs paste absolute `giovannini_nuovo` iCloud paths.
- Deploy looks for `logo.jpg` at repo root; asset is `assets/logo.png`.
- Package platform macOS 13 vs packaged `LSMinimumSystemVersion` 26.0.

## 9. Commands Executed

| Command | Exit | Result |
|---------|------|--------|
| `pwd` / `git status` / `git branch` / `git remote` / `git log -10` / `du -sh .` | 0 | Initial state captured |
| `git submodule status` | 0 | No submodules |
| Structure `find` / `du` | 0 | Map produced |
| `swift --version` | 0 | Swift 6.4, arm64-apple-macosx27.0 |
| `python3 --version` | 0 | 3.14.6 |
| `zsh --version` | 0 | 5.9 |
| `uname -m` / `sw_vers` | 0 | arm64; macOS 27.0 |
| `git diff --check` | 0 | No whitespace errors reported |
| `swift build` | **1** | PersonalOSKit path inaccessible |
| `zsh -n scripts/SystemOrganizer/*.sh` | 0 | Syntax OK |
| `bash -n scripts/git-push-clean.sh` | 0 | Syntax OK |
| `python3 -m py_compile scripts/SystemOrganizer/*.py` | 0 | Compile OK |
| Existence checks for PersonalOSKit / other-user home | 0 | Both missing |
| Installed app codesign / plist / `pgrep` | 0 | Ad-hoc signed v2.1.0; not running |
| Read-only App Support path inventory | 0 | 27 automations; many enabled; no machines/vaults files |
| `os.path.samefile` Documents vs iCloud path | 0 | Same directory |
| `swift test` | **Skipped** | Dependency missing; would fail same as build |
| Deploy / mutating automations | **Skipped** | Destructive / installs to `/Applications` |

## 10. Findings Summary

| ID | Severity | Priority | Category | Finding | Confidence |
|---|---|---|---|---|---|
| AUDIT-001 | High | P0 | Dependency | PersonalOSKit path dependency missing; build/test broken | Confirmed |
| AUDIT-002 | High | P0 | macOS / Shell | Widespread hardcoded `/Users/giovannini_nuovo` paths | Confirmed |
| AUDIT-003 | High | P1 | Reliability | Live enabled automations target missing `$HOME/Documents/scripts/*` | Confirmed |
| AUDIT-004 | High | P1 | Reliability | Destructive scripts (desktop move, trash downloads, quit-all) + stale hardcoded homes | Confirmed |
| AUDIT-005 | High | P1 | Correctness | Global hotkey monitor not retained; feature ineffective | Confirmed |
| AUDIT-006 | Medium | P1 | Reliability | `ProcessManager` has no execution timeout | High confidence |
| AUDIT-007 | Medium | P2 | Documentation | Docs/scripts disagree with repo layout and host | Confirmed |
| AUDIT-008 | Medium | P2 | Architecture | Ambition–capacity mismatch: portfolio orchestration vs maintainable personal hub | High confidence |
| AUDIT-009 | Medium | P2 | Testing | Only ProcessManager covered; critical paths untested | Confirmed |
| AUDIT-010 | Medium | P2 | Dependency | Unused `ShellRunner` product; no lockfile for local kit | Confirmed |
| AUDIT-011 | Medium | P2 | Shell | Deploy hardcodes PROJECT + wrong logo path; cannot redeploy | Confirmed |
| AUDIT-012 | Low | P3 | Repository hygiene | Broken ref `main 2`; debug instrumentation in push script; local junk | Confirmed |
| AUDIT-013 | Low | P3 | Security | Ad-hoc signing; SSH arbitrary remote command by design | Confirmed |
| AUDIT-014 | Informational | P3 | macOS | Missing Accessibility usage string; incomplete quick-launch | Confirmed |

## 11. Critical Findings

None at Critical severity. No committed credentials, private keys, or confirmed remote RCE against untrusted input were found. Build failure and path breakage are treated as High (below), not Critical, because an installed binary still exists and this is a single-user local tool.

## 12. High Findings

### [AUDIT-001] PersonalOSKit filesystem dependency missing — cannot build or test

- Severity: High
- Priority: P0
- Confidence: Confirmed
- Category: Dependency
- File: `Package.swift`
- Location: `dependencies` / products `ShellRunner`, `OllamaClient` (lines 12–21)
- Evidence:
  - `.package(path: "/Users/giovannini_nuovo/Developer/PersonalOSKit")`
  - Path absent for both `giovannini_nuovo` and current user `Developer/PersonalOSKit`
  - `swift build` exit 1: package cannot be accessed
  - `.build/workspace-state.json` still records that filesystem location
  - `OllamaManager.swift` imports `OllamaClient` (required); `ShellRunner` never imported in Sources
- Impact:
  - Source tree cannot be rebuilt, tested, or redeployed on this workstation.
  - Fresh clones are non-operational without a private sibling checkout at a fixed absolute path.
- Recommendation:
  - Relocate PersonalOSKit under a portable relative path, SPM URL, or vendor only the `OllamaClient` surface used here; drop unused `ShellRunner` until needed.
- Validation:
  - `swift build` and `swift test` succeed without absolute foreign home paths.

### [AUDIT-002] Hardcoded former username paths across Package, config, scripts, and docs

- Severity: High
- Priority: P0
- Confidence: Confirmed
- Category: macOS / Shell
- File: `Package.swift`, `config/projects.json`, `config/repo_roots.json`, `scripts/SystemOrganizer/*.sh`, docs
- Location: ~25 tracked files still reference `giovannini_nuovo` (ripgrep count)
- Evidence:
  - Commit `90d2dd5` message claimed dynamic home resolution; many scripts still hardcode absolute homes (e.g. `organize_desktop_to_documents.sh` Desktop/ARCHIVE, `clean_downloads_older_than_5_days.sh`, `deploy_system_organizer.sh` `PROJECT=`, `morning_startup_routine.sh`, `config/repo_roots.json` scan root).
  - `/Users/giovannini_nuovo` home directory does not exist on this host.
  - Default automations in `AutomationManager.defaultAutomations()` use `$HOME/.../System_Org 2/...` (better), but sibling project scripts do not.
- Impact:
  - Inventory, portfolio validation, deploy, morning startup, desktop/downloads automations fail or no-op incorrectly after username/machine change.
  - If a same-named account were ever present, scripts could operate on the wrong user's files.
- Recommendation:
  - Standardize on `REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"`, `"$HOME"`, and config relative to repo; regenerate `config/projects.json` / `repo_roots.json` for the current machine (or template + local override gitignored).
- Validation:
  - `rg giovannini_nuovo` returns only intentional historical notes (or zero in executable paths); `project_safe_validation.sh` finds configured projects.

### [AUDIT-003] Live Application Support has enabled scheduled automations with missing scripts

- Severity: High
- Priority: P1
- Confidence: Confirmed
- Category: Reliability
- File: `~/Library/Application Support/SystemOrganizer/automations.json` (runtime; not in repo)
- Location: Enabled entries `calendar_summary`, `organize_desktop`, `terminal_tasks`, etc.
- Evidence:
  - Paths like `$HOME/Documents/scripts/calendar_summary.applescript` — `$HOME/Documents/scripts` does not exist.
  - Schedules include `daily_9am`, `daily_6pm`, `daily_midnight`.
  - On app launch, `AutomationManager` schedules enabled non-manual automations; runs would fail with “Script file not found”.
- Impact:
  - Noisy failure notifications; false sense that daily routines run; schedule churn without useful work.
- Recommendation:
  - Disable or delete dead entries; point remaining ones at existing `scripts/SystemOrganizer` paths; keep backups already created by configure script.
- Validation:
  - Re-scan enabled automations: every `scriptPath` exists after expand; no unexpected scheduled fires.

### [AUDIT-004] Destructive personal scripts combined with stale absolute paths / enabled live entries

- Severity: High
- Priority: P1
- Confidence: Confirmed
- Category: Reliability
- File: `scripts/SystemOrganizer/organize_desktop_to_documents.sh`, `clean_downloads_older_than_5_days.sh`, `evening_shutdown_routine.sh`
- Location: Full scripts; live App Support enables several of these (`schedule: manual` today)
- Evidence:
  - Desktop organizer `mv`s all Desktop items into an archive under hardcoded former user paths.
  - Downloads cleaner sends aged items to Trash via Finder AppleScript; hardcoded Downloads path.
  - Evening routine AppleScript Cmd+S and quits essentially all foreground apps; `pkill`s project servers.
  - Default code enables `organize_desktop` on `daily_6pm` for fresh installs (`AutomationManager.defaultAutomations`).
  - `fulofilo_run_daily_guarded.sh` is enabled in live config (guarded by env var — safer — but still wrong PROJECT path).
- Impact:
  - Accidental run can disrupt workspace; wrong-path hardcodes currently mitigate cross-user damage on this host but cause silent/failed operations; on the original account naming, damage potential is high.
- Recommendation:
  - Keep destructive automations disabled by default; require `$HOME`-based paths; confirm dialogs or dry-run flags for desktop/downloads/evening; leave fulofilo behind `ALLOW_PROJECT_DATA_WRITES=1` (already present).
- Validation:
  - Dry-run mode prints planned moves; evening script refuses without explicit confirm env; defaults create all `isEnabled: false` for destructive IDs.

### [AUDIT-005] Global hotkey monitor return value discarded

- Severity: High
- Priority: P1
- Confidence: Confirmed
- Category: Correctness
- File: `Sources/SystemOrganizerApp.swift`
- Location: `registerGlobalHotkey()` lines 74–88; field `globalMonitor` unused
- Evidence:
  - `NSEvent.addGlobalMonitorForEvents(...)` result is not assigned to `globalMonitor`.
  - Apple requires retaining the monitor object; otherwise it is released and never fires.
  - `showQuickLaunch` is never set true; hotkey only attempts `NSApp.activate` even if retained.
- Impact:
  - Documented ⌘⌥Space quick-launch does not work.
- Recommendation:
  - Store monitor in `globalMonitor`; wire UI for quick launch or remove dead API/fields.
- Validation:
  - With Accessibility granted, hotkey activates expected UI reliably across focus changes.

## 13. Medium Findings

### [AUDIT-006] Script execution has no timeout

- Severity: Medium
- Priority: P1
- Confidence: High confidence
- Category: Reliability
- File: `Sources/AutomationManager.swift`
- Location: `ProcessManager.executeScript` — `waitUntilExit()` (~513–522)
- Evidence:
  - No `terminationHandler` deadline, no `interrupt`, no wall-clock timeout.
  - `runningAutomations` prevents re-entry until completion; hung script blocks that automation indefinitely.
  - Same pattern in SSH execute and Git helpers.
- Impact:
  - One stuck `npm`/`make`/SSH can stall UX and chaining.
- Recommendation:
  - Add a configurable timeout (e.g. 5–15 minutes default) then `terminate`/`interrupt`.
- Validation:
  - Test with `sleep 999` inline script; expect failure within timeout.

### [AUDIT-007] Documentation stale relative to implementation and host

- Severity: Medium
- Priority: P2
- Confidence: Confirmed
- Category: Documentation
- File: `docs/installation-guide.md`, `docs/build-and-distribution.md`, `docs/quick-start.md`, others
- Location: Absolute path blocks; Target OS 26.6
- Evidence:
  - Docs require macOS 26.6; host is 27.0; Package allows 13+.
  - Almost all “copy-paste” commands use `/Users/giovannini_nuovo/...`.
  - Deploy docs reference `logo.jpg`; repo has `assets/logo.png`.
  - README is accurate at a high level (`swift build` / relative deploy) but incomplete vs docs.
- Impact:
  - Operators follow non-working commands; onboarding friction after machine rename.
- Recommendation:
  - Prefer repo-relative commands; document PersonalOSKit prerequisite; align OS claims with Package.swift.
- Validation:
  - Walkthrough from clean clone instructions succeeds on current Mac.

### [AUDIT-008] Ambition–capacity mismatch in portfolio automation layer

- Severity: Medium
- Priority: P2
- Confidence: High confidence
- Category: Architecture
- File: `scripts/SystemOrganizer/`, `config/projects.json`
- Location: Morning/evening, finance, fulofilo, GMC no-ops, portfolio health
- Evidence:
  - Many wrappers for sibling projects absent on this machine; GMC scripts already disabled placeholders.
  - Config projects all under former username paths → validation fails wholesale.
  - App itself is a coherent automation runner; surrounding “personal OS” scripts dominate complexity.
- Impact:
  - Maintenance cost and false failures in health reports; distracts from keeping the core app buildable.
- Recommendation:
  - Defer/archive inactive project wrappers; keep only scripts for projects that exist; generate inventory from `$HOME`-relative roots.
- Validation:
  - `project_portfolio_health.sh` / `project_safe_validation.sh` exit meaningfully green/red against real trees only.

### [AUDIT-009] Thin automated tests

- Severity: Medium
- Priority: P2
- Confidence: Confirmed
- Category: Testing
- File: `Tests/SystemOrganizerTests/ProcessManagerTests.swift`
- Location: Entire suite (4 tests)
- Evidence:
  - Covers inline script success/failure, missing path, `$HOME` expand only.
  - No tests for scheduling, persistence, chaining, Git discovery, Ollama failure modes, path defaults.
  - Suite cannot run until AUDIT-001 fixed; test target depends on executable product.
- Impact:
  - Regressions in schedulers/persistence/deploy easily ship unnoticed.
- Recommendation:
  - After build restore: add unit tests for `nextFireDate`, encode/decode automations, expandPath edge cases; keep script integration optional/manual.
- Validation:
  - `swift test` green with new cases.

### [AUDIT-010] Unused ShellRunner dependency and unreproducible local kit pin

- Severity: Medium
- Priority: P2
- Confidence: Confirmed
- Category: Dependency
- File: `Package.swift`
- Location: products list; no `Package.resolved`
- Evidence:
  - Only `import OllamaClient` in Sources; `ShellRunner` unused.
  - Path dependency yields no portable lock metadata for CI/clones.
- Impact:
  - Extra coupling to PersonalOSKit surface; unclear version identity.
- Recommendation:
  - Depend only on used products; prefer versioned remote or documented relative sibling path.
- Validation:
  - `swift package show-dependencies` resolves without unused products; build OK.

### [AUDIT-011] Deploy script not portable on current workstation

- Severity: Medium
- Priority: P2
- Confidence: Confirmed
- Category: Shell
- File: `scripts/SystemOrganizer/deploy_system_organizer.sh`
- Location: `PROJECT=...` line 4; `logo.jpg` lines 114–116
- Evidence:
  - Absolute PROJECT under other username; would `cd` fail or wrong tree.
  - Packaging skips logo because `logo.jpg` absent (png lives under `assets/`).
  - Otherwise solid: `set -euo pipefail`, arm64 gate, backup, ad-hoc codesign, configure hook.
- Impact:
  - Documented one-command deploy does not work here; installed app ages (binary dated 2026-06-04).
- Recommendation:
  - `PROJECT="$(cd "$(dirname "$0")/../.." && pwd)"`; copy `assets/logo.png` if present.
- Validation:
  - Deploy from this clone updates `/Applications/SystemOrganizer.app` and launches.

## 14. Low and Informational Findings

### [AUDIT-012] Repository hygiene debt

- Severity: Low
- Priority: P3
- Confidence: Confirmed
- Category: Repository hygiene
- File: `.git/refs/heads/main 2`, `scripts/git-push-clean.sh`, `scripts/SystemOrganizer/__pycache__/`, `archive/`
- Location: refs; script debug region; pycache
- Evidence:
  - Branch ref named `main 2` (space) — git warns on `git branch -a`.
  - `git-push-clean.sh` contains Cursor agent debug NDJSON logging to a hardcoded `/Users/eduardofgiovannini/Developer/.cursor/...` path; stages `git add -A`; interactive push to `main`; uncommitted modification present.
  - `__pycache__` present under scripts (gitignored pattern exists).
  - `archive/SystemOrganizer.tar.gz` local, ignored — fine.
- Impact:
  - Confusing git UX; one-shot script risk if run carelessly; minor clutter.
- Recommendation:
  - Delete broken ref; strip debug logging from push helper or move to archive; avoid running push helper in agent sessions.
- Validation:
  - `git branch` clean; script has no `/Users/.../.cursor/debug` writes.

### [AUDIT-013] Ad-hoc code signing and privileged local SSH UX

- Severity: Low
- Priority: P3
- Confidence: Confirmed
- Category: Security
- File: `deploy_system_organizer.sh`; `Sources/RemoteControlView.swift`
- Location: `codesign --sign -`; `executeCommand` SSH argv
- Evidence:
  - Ad-hoc signature, no Team ID — expected for personal local deploy; Gatekeeper friction possible.
  - UI sends arbitrary remote commands over SSH `BatchMode` — appropriate for personal admin tool; no authz beyond local Mac access.
- Impact:
  - Anyone with local GUI access can trigger remote commands configured in App Support.
- Recommendation:
  - Keep personal-only; optional confirm for remote exec; consider Apple Development signing if sharing between your Macs.
- Validation:
  - N/A beyond operator acceptance.

### [AUDIT-014] Accessibility usage description missing; quick-launch incomplete

- Severity: Informational
- Priority: P3
- Confidence: Confirmed
- Category: macOS
- File: Deploy-generated Info.plist; `SystemOrganizerApp.swift`
- Location: Missing `NSAccessibilityUsageDescription`; `showQuickLaunch` unused
- Evidence:
  - Installed Info.plist has Calendar/AppleEvents/Notifications strings; no Accessibility usage string while calling `AXIsProcessTrustedWithOptions`.
  - Quick-launch panel state never used.
- Impact:
  - Weaker permission UX; dead code noise.
- Recommendation:
  - Add usage description in deploy plist writer; finish or remove quick-launch.
- Validation:
  - System Settings shows purpose string when prompting.

## 15. Security Assessment

- **Secrets in repo:** No confirmed API keys, `.env`, PEM, or `Secrets.swift` tracked. `.gitignore` correctly excludes `.env`, keys, `Secrets.swift`.
- **Risky patterns:** Arbitrary local script execution (by design); SSH remote command execution (by design); evening shutdown / desktop moves (destructive); `zsh -lc` of `validate_cmd` from JSON (`project_safe_validation.sh`) — trust config files.
- **Supply chain:** Single private path dependency PersonalOSKit — high availability risk, low public supply-chain exposure.
- **Network:** Ollama localhost; SSH outbound; no cloud backend found.
- **Verdict:** Acceptable threat model for a personal automation hub **if** paths and live automations are corrected; not safe to treat as multi-user software.

## 16. Correctness Assessment

- Core automation run path is coherent: expand path → dispatch by extension → capture exit code → history/notifications/chains.
- Clear defects: unreained global monitor (AUDIT-005); incomplete hotkey feature; defaults/scripts path drift after user rename; deploy logo mismatch.
- Scheduling uses one-shot `Timer` reschedule — correct wall-clock intent, but only while app runs (no LaunchAgent) — document as limitation.
- Silent `try?` on JSON write can hide persistence failures (localized reliability issue).

## 17. Reliability and Operational Stability

| Area | Assessment |
|------|------------|
| Build/redeploy | Broken until PersonalOSKit + PROJECT path fixed |
| Installed app | Present, ad-hoc signed, not running |
| Live automations | Multiple enabled broken paths; several destructive scripts enabled (manual) |
| Monitoring | 5s metrics timer; SSH check with ConnectTimeout |
| Backups | Configure script backs up automations; deploy backs up prior `.app` |
| Logging | In-memory automation logs + notifications; no log rotation subsystem |
| Hung processes | No script timeout (AUDIT-006) |
| Machine coupling | High — username and iCloud absolute paths |

**Operational verdict:** Not stably operable from source on this host; installed binary may still run older build with mixed/live automation config risks.

## 18. Architecture and Complexity Assessment

- **Good:** Clear folder layout per `AGENTS.md`; Application Support persistence; guarded fulofilo write entrypoint; Obsidian path resolver uses `$HOME`.
- **Weak:** Dual sources of truth for script roots (defaults vs configure.py vs hardcoded sh); portfolio scripts as a second product inside the repo; Private kit as absolute path.
- **Ambition–Capacity Mismatch:** Explicit (AUDIT-008). Simplify toward “Swift runner + portable scripts for this repo,” archive inactive project adapters.

## 19. Dependency Assessment

| Dependency | Status |
|------------|--------|
| PersonalOSKit (path) | **Broken / missing** |
| OllamaClient product | Required by `OllamaManager` |
| ShellRunner product | Unused |
| System frameworks | Normal |
| Python | stdlib-only scripts; no requirements.txt (OK) |
| Lockfile | Absent (path dep) |

Do not expand dependency surface until PersonalOSKit resolution strategy is decided.

## 20. Testing Assessment

- Command: `swift test` (documented; unverified here due to AUDIT-001).
- Coverage focus: ProcessManager only — insufficient for failure-critical scheduling/persistence.
- Side effects: inline tests run real `/bin/bash` — acceptable and useful.
- Gap: no CI to enforce tests.

## 21. Documentation Assessment

| Claim | Reality |
|-------|---------|
| `swift build` / `swift test` | Fail without PersonalOSKit |
| Absolute deploy paths | Wrong username on this Mac |
| macOS 26.6 target | Host 27.0; Package 13+; plist 26.0 |
| Scripts root under giovannini_nuovo | Same tree via iCloud alias under **current** user path, but literals still wrong user |
| README relative paths | Closer to truth than long docs |

## 22. macOS and Apple-Specific Assessment

- arm64-only deploy gate — matches host.
- SMAppService launch-at-login — appropriate for macOS 13+.
- Ad-hoc codesign — personal OK.
- Accessibility / AppleEvents / Calendar permissions required for full feature set.
- Hardcoded `/Users/giovannini_nuovo` — primary macOS portability defect.
- No sandbox entitlements file in repo; app appears non-sandboxed (needed for broad automation).
- Installed binary links system frameworks only (no embedded PersonalOSKit dylib visible via `otool -L` — likely statically linked at build time).

## 23. Shell Script Assessment

**Strengths:** Many scripts use `set -euo pipefail` / `set -uo pipefail`; mktemp usage in Obsidian wrappers; fulofilo guard env; configure.py atomic JSON replace; deploy backup/codesign/verify.

**Weaknesses:** Absolute user paths; morning routine starts services with hardcoded trees; evening shutdown aggressive; `git-push-clean.sh` interactive + debug logging + `git add -A`; clean_downloads / organize_desktop destructive; GMC already correctly stubbed.

## 24. Repository Hygiene

- `.gitignore` solid for `.build`, `dist`, secrets, `__pycache__`.
- Local artifacts present but ignored.
- Uncommitted change only on `git-push-clean.sh`.
- Broken branch ref `main 2`.
- Fresh clone **cannot** run without PersonalOSKit + path fixes — clone is not self-contained.

## 25. Prioritized Remediation Plan

### Stage 0 — Preserve and Validate

- Do not run deploy or enabled destructive automations until paths reviewed.
- Backup `~/Library/Application Support/SystemOrganizer/` (already has bak files; copy again).
- Confirm PersonalOSKit location or recover from backup/other machine.
- **Validation:** Backup present; PersonalOSKit decision documented.
- **Rollback:** Restore App Support from bak; reinstall prior `dist/deploy-backups` app if needed.

### Stage 1 — Critical Stabilization

1. Fix PersonalOSKit dependency (AUDIT-001) — unblock `swift build` / `swift test`.
2. Replace hardcoded username paths in Package, config, deploy, and scripts that run on this Mac (AUDIT-002, AUDIT-011).
3. Disable/fix live broken scheduled automations (AUDIT-003).
- **Validation:** `swift test` green; `rg giovannini_nuovo` clean in executable configs/scripts; enabled automations all resolve.
- **Do not yet:** Rewrite UI, add cloud sync, or mass-delete archive.

### Stage 2 — Reliability Improvements

- Retain global hotkey monitor or remove feature (AUDIT-005).
- Add ProcessManager timeout (AUDIT-006).
- Default-disable destructive automations; `$HOME` in desktop/downloads scripts (AUDIT-004).
- **Validation:** Timeout test; hotkey manual test; dry-run desktop script.

### Stage 3 — Simplification

- Archive or gate inactive portfolio wrappers (AUDIT-008).
- Drop unused ShellRunner (AUDIT-010).
- Align docs to relative commands (AUDIT-007).
- **Validation:** Health scripts only reference existing projects; docs dry-run.

### Stage 4 — Maintainability

- Expand unit tests (AUDIT-009); optional lightweight CI on `macos-latest` if kit becomes public/vendored.
- Remove broken git ref and push-script debug (AUDIT-012).
- Accessibility usage string (AUDIT-014).

**Do not attempt yet:** Multi-user packaging, App Store submission, replacing SwiftUI with another stack, automated repo moves.

## 26. Quick Wins

1. Disable live automations whose `scriptPath` does not exist.
2. Change `deploy_system_organizer.sh` `PROJECT` to script-relative repo root.
3. Point deploy logo copy at `assets/logo.png`.
4. Remove `ShellRunner` from `Package.swift` products list once kit resolves.
5. Replace `DESKTOP`/`DOWNLOADS`/`REPORT_DIR` hardcodes with `"$HOME/..."`.
6. Fix `config/repo_roots.json` scan_roots to current `$HOME` GitHub folder (or relative generation).
7. Delete `.git/refs/heads/main 2`.
8. Strip agent debug logging from `scripts/git-push-clean.sh` (or archive the script).
9. Assign `globalMonitor = NSEvent.addGlobalMonitor...`.
10. Document PersonalOSKit prerequisite in README in 3 lines.

## 27. Deferred Improvements

- LaunchAgent/SMAppService helper for schedules when UI app is quit.
- Development signing / notarization.
- Richer XCTest for schedulers and JSON persistence.
- CI matrix.
- Unifying ProcessManager with PersonalOSKit ShellRunner (only if kit returns and API fits).
- Completing quick-launch panel UX.

## 28. Unresolved Questions

1. Where should PersonalOSKit live going forward?
2. Is `giovannini_nuovo` permanently retired, or must dual-home support remain?
3. Are `$HOME/Documents/scripts/*` automations intentionally pending recreation?
4. Should evening/desktop automations remain in-product or move to Shortcuts?
5. Is the June 2026 installed binary still the desired runtime until rebuild works?

## 29. Final Recommendation

Treat this repository as a **valuable personal automation shell whose build and path layer are currently broken after a machine/user migration**. Stabilize in this order: **restore PersonalOSKit → eliminate hardcoded foreign homes → sanitize live automations → fix hotkey/timeout → then simplify portfolio scripts and docs**. Do not invest in new features until `swift build`, `swift test`, and a relative-path deploy succeed on this workstation.

---

*Audit completed 2026-07-29. Only file created/updated by this audit: `REPOSITORY_AUDIT.md`.*
