#!/bin/zsh
set -euo pipefail

# Destructive: requires explicit confirmation.
# Set CONFIRM_EVENING_SHUTDOWN=1 to allow the routine to run.
if [[ "${CONFIRM_EVENING_SHUTDOWN:-0}" != "1" ]]; then
  echo "Refusing evening shutdown: set CONFIRM_EVENING_SHUTDOWN=1 to proceed."
  exit 2
fi

refused_file="$(/usr/bin/mktemp /tmp/system_organizer_refused.XXXXXX)"

save_and_quit_apps() {
  /usr/bin/osascript "$refused_file" <<'APPLESCRIPT'
on run argv
  set refusedPath to item 1 of argv
  set ignoredApps to {"Finder", "System Events", "SystemOrganizer", "Dock", "loginwindow"}

  tell application "System Events"
    set appNames to name of every process whose background only is false
  end tell

  repeat with appName in appNames
    set appNameText to appName as text
    if ignoredApps does not contain appNameText then
      try
        tell application appNameText to activate
        delay 0.2
        tell application "System Events" to keystroke "s" using command down
        delay 0.4
        tell application appNameText to quit
      end try
    end if
  end repeat

  delay 5

  set refusedApps to {}
  tell application "System Events"
    set remainingApps to name of every process whose background only is false
  end tell

  repeat with appName in remainingApps
    set appNameText to appName as text
    if ignoredApps does not contain appNameText then
      set end of refusedApps to appNameText
    end if
  end repeat

  if refusedApps is not {} then
    set AppleScript's text item delimiters to linefeed
    set refusedText to refusedApps as text
    set AppleScript's text item delimiters to ""
    do shell script "printf %s " & quoted form of refusedText & " > " & quoted form of refusedPath
  end if
end run
APPLESCRIPT
}

stop_project_servers() {
  /usr/bin/pkill -f "manage.py runserver 127.0.0.1:8000|manage.py runserver" 2>/dev/null || true
  /usr/bin/pkill -f "vite.*finance-tracker|npm run dev" 2>/dev/null || true
  /usr/bin/pkill -f "uvicorn app.main:app.*8012" 2>/dev/null || true
}

clean_temp_folders() {
  /usr/bin/find /tmp -maxdepth 1 -user "$(whoami)" -type f -mtime +1 -delete 2>/dev/null || true
}

save_and_quit_apps
stop_project_servers
clean_temp_folders

if [[ -s "$refused_file" ]]; then
  refused_apps="$(/bin/cat "$refused_file")"
  /usr/bin/osascript -e "display alert \"Some apps did not close\" message \"These apps may need manual attention:\\n$refused_apps\" as warning"
  echo "Some apps refused to close:"
  echo "$refused_apps"
else
  echo "Saved open apps, requested graceful quit, stopped project servers, and cleaned temporary files."
fi

/bin/rm -f "$refused_file"
