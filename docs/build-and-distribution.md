# Build And Distribution

## Debug Build

```bash
cd "$(git rev-parse --show-toplevel)"
swift build
```

## Release Build

```bash
cd "$(git rev-parse --show-toplevel)"
swift build -c release
```

The release binary is:

```text
.build/release/SystemOrganizer
```

## Local App Bundle

If packaging as a `.app`, copy the release binary into:

```text
SystemOrganizer.app/Contents/MacOS/SystemOrganizer
```

Use SwiftPM as the canonical source of truth. The checked-in `project.pbxproj` is not currently a complete Xcode project.

## Preflight

```bash
swift test
zsh -n scripts/SystemOrganizer/*.sh
scripts/SystemOrganizer/repo_health_check.sh
scripts/SystemOrganizer/project_safe_validation.sh
```

## One-Command Local Deploy

For this personal Apple Silicon workstation, deploy the real local app with:

```zsh
`$HOME/Documents/GitHub`/System_Org\ 2/scripts/SystemOrganizer/deploy_system_organizer.sh
```

The deploy script:

- verifies macOS and arm64 host architecture
- runs the Swift test suite
- builds the release binary for arm64
- packages `/Applications/SystemOrganizer.app`
- creates a backup of any existing installed app
- signs the bundle locally with ad-hoc codesigning
- installs/updates live System Organizer automations
- launches the app and verifies the running process
- prints the final repo health report
