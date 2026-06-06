#!/bin/zsh
set -euo pipefail

APP="/Users/giovannini_nuovo/Library/Mobile Documents/com~apple~CloudDocs/Documents/GitHub/giovannini-finance/Personal_Tracker_macros"
RUN_DIR="/Users/giovannini_nuovo/Library/Mobile Documents/com~apple~CloudDocs/Documents/GitHub/giovannini-finance/.run"
UVICORN="$APP/.venv/bin/uvicorn"

mkdir -p "$RUN_DIR"

if [[ ! -d "$APP" ]]; then
  echo "Missing finance macro API project: $APP"
  exit 1
fi

if [[ ! -x "$UVICORN" ]]; then
  echo "Missing uvicorn: $UVICORN"
  echo "Bootstrap the project virtualenv before starting the API."
  exit 1
fi

if /usr/bin/pgrep -f "uvicorn app.main:app.*8012" >/dev/null 2>&1; then
  echo "Finance macro API already appears to be running at http://127.0.0.1:8012"
  exit 0
fi

cd "$APP"
nohup "$UVICORN" app.main:app --host 127.0.0.1 --port 8012 > "$RUN_DIR/finance_macros_api.log" 2>&1 &
echo $! > "$RUN_DIR/finance_macros_api.pid"
echo "Started finance macro API at http://127.0.0.1:8012"
