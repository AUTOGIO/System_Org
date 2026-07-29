#!/bin/zsh
set -euo pipefail

DOWNLOADS="${HOME}/Downloads"
DAYS=5
DRY_RUN="${DRY_RUN:-0}"

if [[ ! -d "$DOWNLOADS" ]]; then
  echo "Downloads folder not found: $DOWNLOADS"
  exit 1
fi

moved_count=0

while IFS= read -r -d '' item; do
  if [[ "$DRY_RUN" == "1" ]]; then
    echo "DRY_RUN: would trash $item"
  else
    /usr/bin/osascript - "$item" <<'APPLESCRIPT'
on run argv
  tell application "Finder"
    delete POSIX file (item 1 of argv)
  end tell
end run
APPLESCRIPT
  fi
  moved_count=$((moved_count + 1))
done < <(/usr/bin/find "$DOWNLOADS" -mindepth 1 -maxdepth 1 -mtime +"$DAYS" -print0)

if [[ "$DRY_RUN" == "1" ]]; then
  echo "Dry-run: planned $moved_count item(s) older than $DAYS days from Downloads to Trash."
else
  echo "Moved $moved_count item(s) older than $DAYS days from Downloads to Trash."
fi
