#!/bin/zsh
set -euo pipefail

# Write a Markdown note into the resolved Obsidian vault.
#
# Usage:
#   write_obsidian_note.sh --title "Title" --folder "System Organizer/Reports" --content "..."
#   echo "content" | write_obsidian_note.sh --title "Title" --folder "System Organizer/Reports"
#
# Output:
#   Prints the final note path to stdout.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VAULT="$("$SCRIPT_DIR/obsidian_resolve_vault.sh")"

title=""
folder=""
content=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --title)
      title="${2:-}"; shift 2
      ;;
    --folder)
      folder="${2:-}"; shift 2
      ;;
    --content)
      content="${2:-}"; shift 2
      ;;
    -h|--help)
      echo "Usage: $0 --title <title> --folder <folder> [--content <text>]"; exit 0
      ;;
    *)
      echo "Unknown arg: $1" >&2; exit 2
      ;;
  esac
done

if [[ -z "$title" ]]; then
  echo "ERROR: --title is required" >&2
  exit 2
fi
if [[ -z "$folder" ]]; then
  echo "ERROR: --folder is required" >&2
  exit 2
fi

if [[ -z "$content" ]]; then
  # Read stdin if available
  if [[ ! -t 0 ]]; then
    content="$(/bin/cat)"
  else
    content=""
  fi
fi

safe_title="$title"
safe_title="${safe_title//\//-}"
safe_title="${safe_title//:/-}"

date_prefix="$(/bin/date +%F)"
note_dir="$VAULT/$folder"
note_path="$note_dir/$date_prefix - $safe_title.md"

mkdir -p "$note_dir"

{
  echo "---"
  echo "created: $(/bin/date -Iseconds)"
  echo "source: System Organizer"
  echo "title: \"$title\""
  echo "---"
  echo
  echo "$content"
} > "$note_path"

echo "$note_path"
