# System Organizer

Personal local-first macOS automation hub (SwiftUI / SwiftPM): scripts, repo health, Obsidian reports, Git status, Ollama, Calendar, and SSH helpers.

**Prerequisite:** clone [PersonalOSKit](https://github.com/AUTOGIO/PersonalOSKit) as a sibling of this repo (`../PersonalOSKit`). Package.swift depends on it for `OllamaClient` only.

**Build / test** (recommended — avoids iCloud Documents Finder xattr codesign failures on `*.xctest`):

```zsh
swift test --scratch-path /tmp/SystemOrganizer-spm-build
swift build -c release
```

**Deploy:** `./scripts/SystemOrganizer/deploy_system_organizer.sh`  
(Deploy already runs tests with the scratch path above.)

**Where things live:** `Sources/` app code · `Tests/` tests · `scripts/` helpers · `config/` settings · `assets/` images · `docs/` guides · `docs/prompts/` AI prompts · `archive/` old files kept for reference
