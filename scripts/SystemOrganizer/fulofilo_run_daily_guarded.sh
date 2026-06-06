#!/bin/zsh
set -euo pipefail

PROJECT="/Users/giovannini_nuovo/Library/Mobile Documents/com~apple~CloudDocs/Documents/GitHub/fulofilo-analytics"

cat <<'WARNING'
This automation can modify fulofilo-analytics project data.
Run only after you have confirmed the project's own backup/export policy.

To allow execution, set:
  ALLOW_PROJECT_DATA_WRITES=1
WARNING

if [[ "${ALLOW_PROJECT_DATA_WRITES:-0}" != "1" ]]; then
  echo "Refusing to run mutating project automation without ALLOW_PROJECT_DATA_WRITES=1."
  exit 2
fi

if [[ ! -d "$PROJECT" ]]; then
  echo "Missing project: $PROJECT"
  exit 1
fi

if [[ ! -x "$PROJECT/.venv/bin/python3" ]]; then
  echo "Missing Python virtualenv: $PROJECT/.venv/bin/python3"
  exit 1
fi

cd "$PROJECT"
make automation-run-daily
