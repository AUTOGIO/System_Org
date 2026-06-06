#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
tmp="$(/usr/bin/mktemp -t sysorg_repo_state_summary.XXXXXX)"
trap 'rm -f "$tmp"' EXIT

"$SCRIPT_DIR/repo_state_summary.sh" | /usr/bin/tee "$tmp"

note_path="$("$SCRIPT_DIR/write_obsidian_note.sh" \
  --title "Repo State Summary" \
  --folder "System Organizer/Reports" \
  --content "$(/bin/cat "$tmp")")"

echo
echo "Saved Obsidian note: $note_path"
