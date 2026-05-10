# System Organizer

A native macOS automation hub built with SwiftUI. Manage scripts, monitor system health, control remote machines via SSH, view calendar events, and integrate with Obsidian — all from a single menu-bar app.

![Platform](https://img.shields.io/badge/platform-macOS%2013%2B-blue)
![Swift](https://img.shields.io/badge/swift-5.9-orange)
![License](https://img.shields.io/badge/license-MIT-green)

---

## Features

| Module | Status | Description |
|---|---|---|
| **Automations** | ✅ Working | Run AppleScript / Python / Shell scripts on a schedule or on demand |
| **Monitoring** | ✅ Working | Real-time CPU, memory, disk charts via native Mach APIs |
| **Remote Control** | ✅ Working | SSH into machines, run commands, check connectivity |
| **Calendar** | ✅ Working | View EventKit events per day with full-access on macOS 14+ |
| **Obsidian** | ✅ Working | Browse vaults, list notes, create new `.md` files |
| **Menu Bar** | ✅ Working | Quick stats + one-click run from the menu bar |
| **CloudKit Sync** | ⚙️ Optional | Opt-in in Settings; requires a signed app with CloudKit entitlement |

---

## Requirements

- macOS 13 Ventura or later (macOS 14 Sonoma recommended)
- Xcode 15+ **or** Swift 5.9 CLI toolchain
- iCloud account (only if CloudKit sync is enabled)

---

## Quick Start

### Build with Xcode
```bash
open System_Org.code-workspace
# Product → Run  (⌘R)
```

### Build with Swift CLI
```bash
cd System_Org
swift build -c release
.build/release/SystemOrganizer
```

---

## Project Structure

```
System_Org/
├── Sources/
│   ├── SystemOrganizerApp.swift   # App entry point, scene setup
│   ├── ContentView.swift          # Root TabView + tab bar
│   ├── DashboardView.swift        # Stats cards + activity feed
│   ├── AutomationsView.swift      # Automation list, search, filter
│   ├── AutomationManager.swift    # Script runner, scheduler, JSON persistence
│   ├── AutomationModel.swift      # Data models (Automation, RemoteMachine, …)
│   ├── MonitoringView.swift       # CPU/memory charts (Swift Charts)
│   ├── MonitoringManager.swift    # Mach API stats, SSH ping
│   ├── RemoteControlView.swift    # SSH machine cards + terminal input
│   ├── CalendarView.swift         # EventKit day view
│   ├── ObsidianView.swift         # Vault browser + note creator
│   ├── SettingsView.swift         # CloudKit toggle, sync interval, log retention
│   ├── MenuBarView.swift          # Menu-bar extra
│   └── CloudKitManager.swift      # Optional CloudKit sync (opt-in)
├── docs/
│   ├── quick-start.md
│   ├── installation-guide.md
│   ├── build-and-distribution.md
│   ├── app-overview.md
│   └── project-summary.md
├── Package.swift
└── README.md
```

---

## Automation Scripts

Scripts live in `~/Documents/scripts/` by default. The runner dispatches by extension:

| Extension | Interpreter |
|---|---|
| `.applescript` / `.scpt` | `/usr/bin/osascript` |
| `.py` | `python3` (via `/usr/bin/env`) |
| `.sh` / `.bash` | `/bin/bash` |

Schedules fire at the correct wall-clock time (not just "24 h from launch"):

| ID | Default time |
|---|---|
| `daily_9am` | 09:00 every day |
| `daily_6pm` | 18:00 every day |
| `daily_midnight` | 00:00 every day |
| `hourly` | Top of each hour |
| `manual` | On-demand only |

Automation state is persisted to:
```
~/Library/Application Support/SystemOrganizer/automations.json
```

---

## CloudKit Sync

Disabled by default to prevent crashes in unsigned/development builds.

To enable:
1. Open **Settings → CloudKit Sync** and toggle **Enable CloudKit Sync**
2. Ensure the app is signed with a provisioning profile that includes the `com.apple.developer.icloud-services` entitlement
3. Set `DISABLE_CLOUDKIT=1` in your scheme's environment variables to force-disable during development

---

## Known Limitations / Roadmap

- [ ] Launch-at-Login via `SMAppService` (toggle exists in UI, not yet wired up)
- [ ] User Notifications for automation results
- [ ] Add/edit/delete automations from the UI (currently read from JSON / defaults)
- [ ] Obsidian note editor (currently create-only)
- [ ] Remote machine config persistence (currently resets on relaunch)

---

## Documentation

See the [`docs/`](docs/) folder for installation, build, and distribution guides.

---

## License

MIT — see `LICENSE` for details.
