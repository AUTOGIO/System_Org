#!/bin/zsh
set -euo pipefail

DESKTOP="/Users/giovannini_nuovo/Desktop"
ARCHIVE_ROOT="/Users/giovannini_nuovo/Documents/Desktop_Archive"
DATE_PREFIX="$(/bin/date +%F)"

mkdir -p "$ARCHIVE_ROOT"/{Screenshots,Images,PDFs,Documents,Archives,Videos,Audio,Other}

category_for_file() {
  local name="$1"
  local lower="${name:l}"

  if [[ "$lower" == screenshot* || "$lower" == screen\ shot* ]]; then
    echo "Screenshots"
    return
  fi

  case "$lower" in
    *.png|*.jpg|*.jpeg|*.gif|*.heic|*.webp|*.tiff|*.bmp) echo "Images" ;;
    *.pdf) echo "PDFs" ;;
    *.doc|*.docx|*.txt|*.rtf|*.md|*.pages|*.numbers|*.key|*.csv|*.xlsx|*.xls|*.ppt|*.pptx) echo "Documents" ;;
    *.zip|*.tar|*.gz|*.tgz|*.rar|*.7z|*.dmg) echo "Archives" ;;
    *.mov|*.mp4|*.m4v|*.avi|*.mkv) echo "Videos" ;;
    *.mp3|*.wav|*.m4a|*.aac|*.flac) echo "Audio" ;;
    *) echo "Other" ;;
  esac
}

unique_destination() {
  local destination="$1"
  local base="${destination:r}"
  local ext="${destination:e}"
  local candidate="$destination"
  local index=1

  while [[ -e "$candidate" ]]; do
    if [[ "$ext" == "$destination" || -z "$ext" ]]; then
      candidate="${destination}_${index}"
    else
      candidate="${base}_${index}.${ext}"
    fi
    index=$((index + 1))
  done

  echo "$candidate"
}

moved_count=0

for item in "$DESKTOP"/*(N); do
  [[ -e "$item" ]] || continue

  name="${item:t}"
  [[ "$name" == ".DS_Store" ]] && continue
  [[ "$name" == "System_Reports" ]] && continue

  category="$(category_for_file "$name")"
  renamed="${DATE_PREFIX}_${name}"
  destination="$(unique_destination "$ARCHIVE_ROOT/$category/$renamed")"

  /bin/mv "$item" "$destination"
  moved_count=$((moved_count + 1))
done

echo "Renamed and moved $moved_count Desktop item(s) into $ARCHIVE_ROOT by type."
