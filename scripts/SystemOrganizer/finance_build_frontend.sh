#!/bin/zsh
set -euo pipefail

APP="/Users/giovannini_nuovo/Library/Mobile Documents/com~apple~CloudDocs/Documents/GitHub/giovannini-finance/finance-tracker"
NPM="/opt/homebrew/bin/npm"
TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-300}"

run_with_timeout() {
  "$@" &
  local pid=$!
  local deadline=$((SECONDS + TIMEOUT_SECONDS))

  while kill -0 "$pid" >/dev/null 2>&1; do
    if (( SECONDS >= deadline )); then
      kill "$pid" >/dev/null 2>&1 || true
      wait "$pid" 2>/dev/null || true
      echo "Timed out after ${TIMEOUT_SECONDS}s: $*"
      exit 124
    fi
    sleep 2
  done

  wait "$pid"
}

if [[ ! -d "$APP" ]]; then
  echo "Missing finance frontend: $APP"
  exit 1
fi

if [[ ! -x "$NPM" ]]; then
  echo "Missing npm at $NPM"
  exit 1
fi

if [[ ! -d "$APP/node_modules" ]]; then
  echo "Missing node_modules in $APP. Run npm install first."
  exit 1
fi

cd "$APP"
run_with_timeout "$NPM" run build
