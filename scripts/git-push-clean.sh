#!/usr/bin/env bash
# ── System Organizer — finalize GitHub restructure ──────────────────────────
# Run this once from Terminal after closing Xcode / VS Code.
# Usage: bash scripts/git-push-clean.sh
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO"

echo "▶ Clearing stale git lock (if any)..."
rm -f .git/index.lock

echo "▶ Staging all changes..."
git add -A

echo "▶ Current status:"
git status --short

echo ""
read -r -p "Proceed with commit and push? [y/N] " confirm
[[ "$confirm" == "y" || "$confirm" == "Y" ]] || { echo "Aborted."; exit 0; }

git commit -m "refactor: audit fixes + GitHub repo restructure

Bug fixes:
- CloudKitManager: fill .temporarilyUnavailable case (compile blocker)
- AutomationManager: dispatch scripts by extension (osascript/.py/bash)
- AutomationManager: scheduler fires at correct wall-clock time, not 24h from launch
- AutomationManager: persist automations to JSON in Application Support
- MonitoringView: store & invalidate history Timer on disappear (memory leak)
- RemoteControlView: executeCommand() moved to background thread (UI freeze)
- CalendarView: use requestFullAccessToEvents on macOS 14+ (deprecated API)

Repo hygiene:
- Add .gitignore (excludes .DS_Store, .app, .tar.gz, .swiftpm user state)
- Add README.md with feature table, structure, script dispatch docs
- Move all .md docs to docs/ with clean ASCII filenames
- Remove .DS_Store, binaries (.app, .tar.gz), Xcode user state from tracking"

echo "▶ Pushing to origin/main..."
git push origin main

echo ""
echo "✅ Done. Visit: https://github.com/AUTOGIO/System_Org"
