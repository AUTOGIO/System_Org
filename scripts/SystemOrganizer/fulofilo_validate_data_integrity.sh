#!/bin/zsh
set -euo pipefail

PROJECT="${HOME}/Documents/GitHub/fulofilo-analytics"

if [[ ! -d "$PROJECT" ]]; then
  echo "Missing project: $PROJECT"
  exit 1
fi

if [[ ! -f "$PROJECT/Makefile" ]]; then
  echo "Missing Makefile in $PROJECT"
  exit 1
fi

if [[ ! -x "$PROJECT/.venv/bin/python3" ]]; then
  echo "Missing Python virtualenv: $PROJECT/.venv/bin/python3"
  exit 1
fi

cd "$PROJECT"
make automation-validate-data-integrity
