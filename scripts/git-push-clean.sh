#!/usr/bin/env bash
# ── System Organizer — finalize GitHub restructure ──────────────────────────
# Run this once from Terminal after closing Xcode / VS Code.
# Usage: bash scripts/git-push-clean.sh
set -euo pipefail

#region agent log
_DEBUG_LOG="/Users/giovannini_nuovo/Developer/.cursor/debug-58fa40.log"
_agent_log() {
  local hid="$1" loc="$2" msg="$3" data="${4:-{}}"
  printf '%s\n' "{\"sessionId\":\"58fa40\",\"hypothesisId\":\"${hid}\",\"location\":\"${loc}\",\"message\":\"${msg}\",\"data\":${data},\"timestamp\":$(($(date +%s)*1000)),\"runId\":\"pre-fix\"}" >> "$_DEBUG_LOG"
}
#endregion

REPO="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO"

#region agent log
_lock_before="false"
[[ -f .git/index.lock ]] && _lock_before="true"
_build_mb="0"
[[ -d .build ]] && _build_mb="$(du -sm .build 2>/dev/null | awk '{print $1}')"
_agent_log "H1" "git-push-clean.sh:startup" "repo state before lock clear" "{\"repo\":\"${REPO}\",\"indexLockBefore\":${_lock_before},\"buildDirMb\":${_build_mb},\"onMain\":$(git branch --show-current 2>/dev/null | grep -qx main && echo true || echo false)}"
#endregion

echo "▶ Clearing stale git lock (if any)..."
rm -f .git/index.lock

if [[ ! -s .git/index ]]; then
  echo "▶ Rebuilding empty/corrupt git index from HEAD..."
  rm -f .git/index
  git reset
fi

#region agent log
_lock_after="false"
[[ -f .git/index.lock ]] && _lock_after="true"
_index_bytes="$(wc -c < .git/index 2>/dev/null | tr -d ' ')"
_agent_log "H1" "git-push-clean.sh:after-lock-rm" "index lock after rm" "{\"indexLockAfter\":${_lock_after},\"indexBytes\":${_index_bytes:-0}}"
#endregion

echo "▶ Staging all changes..."
#region agent log
_add_start=$(date +%s)
#endregion
git add -A
#region agent log
_add_end=$(date +%s)
_staged_build="$(git diff --cached --name-only 2>/dev/null | grep -c '^\.build/' || true)"
_staged_total="$(git diff --cached --name-only 2>/dev/null | wc -l | tr -d ' ')"
_agent_log "H2" "git-push-clean.sh:after-git-add" "staging complete" "{\"gitAddSeconds\":$((_add_end-_add_start)),\"stagedBuildPaths\":${_staged_build},\"stagedTotalPaths\":${_staged_total}}"
#endregion

echo "▶ Current status:"
git status --short

echo ""
read -r -p "Proceed with commit and push? [y/N] " confirm
#region agent log
_tty="false"
[[ -t 0 ]] && _tty="true"
_agent_log "H3" "git-push-clean.sh:after-confirm" "user confirmation" "{\"confirm\":\"${confirm}\",\"stdinIsTty\":${_tty}}"
#endregion
[[ "$confirm" == "y" || "$confirm" == "Y" ]] || { echo "Aborted."; exit 0; }

#region agent log
_commit_start=$(date +%s)
#endregion
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
#region agent log
_commit_end=$(date +%s)
_agent_log "H4" "git-push-clean.sh:after-commit" "commit finished" "{\"commitSeconds\":$((_commit_end-_commit_start)),\"head\":\"$(git rev-parse --short HEAD 2>/dev/null || echo none)\"}"
#endregion

echo "▶ Pushing to origin/main..."
#region agent log
_push_start=$(date +%s)
#endregion
git push origin main
#region agent log
_push_end=$(date +%s)
_agent_log "H5" "git-push-clean.sh:after-push" "push finished" "{\"pushSeconds\":$((_push_end-_push_start))}"
#endregion

echo ""
echo "✅ Done. Visit: https://github.com/AUTOGIO/System_Org"
