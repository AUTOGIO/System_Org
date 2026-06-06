#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
tmp="$(/usr/bin/mktemp -t sysorg_repo_health_check.XXXXXX)"
trap 'rm -f "$tmp"' EXIT

set +e
"$SCRIPT_DIR/repo_health_check.sh" | /usr/bin/tee "$tmp"
exit_code="${pipestatus[1]}"
set -e

note_path="$("$SCRIPT_DIR/write_obsidian_note.sh" \
  --title "Repo Health Check" \
  --folder "System Organizer/Reports" \
  --content "$(/bin/cat "$tmp")")"

echo
echo "Saved Obsidian note: $note_path"
exit "$exit_code"
