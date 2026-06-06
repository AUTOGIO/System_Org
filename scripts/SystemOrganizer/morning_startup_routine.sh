#!/bin/zsh
set -euo pipefail

LIFE_OS_ROOT="/Users/giovannini_nuovo/Library/Mobile Documents/com~apple~CloudDocs/Documents/GitHub/Life_OS"
LIFE_OS_APP="$LIFE_OS_ROOT/lifeos"
FINANCE_ROOT="/Users/giovannini_nuovo/Library/Mobile Documents/com~apple~CloudDocs/Documents/GitHub/giovannini-finance"
FINANCE_APP="$FINANCE_ROOT/finance-tracker"
MACROS_APP="$FINANCE_ROOT/Personal_Tracker_macros"
NPM_BIN="/opt/homebrew/bin/npm"

mkdir -p "$LIFE_OS_ROOT/.run" "$FINANCE_ROOT/.run"

start_life_os() {
  if /usr/bin/pgrep -f "manage.py runserver 127.0.0.1:8000|manage.py runserver" >/dev/null 2>&1; then
    echo "Life_OS already appears to be running."
    return
  fi

  if [[ ! -d "$LIFE_OS_APP" ]]; then
    echo "Life_OS app folder not found: $LIFE_OS_APP"
    return 1
  fi

  (
    cd "$LIFE_OS_APP"
    if [[ -f "venv/bin/activate" ]]; then
      source "venv/bin/activate"
    fi
    make migrate
    nohup python manage.py runserver 127.0.0.1:8000 > "$LIFE_OS_ROOT/.run/web.log" 2>&1 &
    echo $! > "$LIFE_OS_ROOT/.run/web.pid"
  )

  echo "Started Life_OS at http://127.0.0.1:8000/dashboard/"
}

start_finance_frontend() {
  if /usr/bin/pgrep -f "vite.*finance-tracker|npm run dev" >/dev/null 2>&1; then
    echo "giovannini-finance frontend already appears to be running."
    return
  fi

  if [[ ! -d "$FINANCE_APP" ]]; then
    echo "Finance frontend folder not found: $FINANCE_APP"
    return 1
  fi
  if [[ ! -x "$NPM_BIN" ]]; then
    echo "npm not found: $NPM_BIN"
    return 1
  fi
  /bin/chmod +x "$FINANCE_ROOT/.run/run_finance_frontend.sh"

  /usr/bin/osascript <<APPLESCRIPT
tell application "Terminal"
  do script "/bin/zsh '/Users/giovannini_nuovo/Library/Mobile Documents/com~apple~CloudDocs/Documents/GitHub/giovannini-finance/.run/run_finance_frontend.sh'"
end tell
APPLESCRIPT

  echo "Started giovannini-finance frontend."
}

start_finance_macros() {
  if [[ ! -x "$MACROS_APP/.venv/bin/uvicorn" ]]; then
    echo "Finance macro API virtualenv not found. Run: zsh $MACROS_APP/scripts/bootstrap.sh"
    return
  fi
  /bin/chmod +x "$FINANCE_ROOT/.run/run_finance_macros.sh"

  if /usr/bin/pgrep -f "uvicorn app.main:app.*8012" >/dev/null 2>&1; then
    echo "Finance macro API already appears to be running."
    return
  fi

  /usr/bin/osascript <<APPLESCRIPT
tell application "Terminal"
  do script "/bin/zsh '/Users/giovannini_nuovo/Library/Mobile Documents/com~apple~CloudDocs/Documents/GitHub/giovannini-finance/.run/run_finance_macros.sh'"
end tell
APPLESCRIPT

  echo "Started finance macro API at http://127.0.0.1:8012"
}

start_life_os
start_finance_frontend
start_finance_macros

/usr/bin/open "http://127.0.0.1:8000/dashboard/" || true

echo "Morning startup routine complete."
