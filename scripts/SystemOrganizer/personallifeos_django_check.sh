#!/bin/zsh
set -euo pipefail

APP="${HOME}/Documents/GitHub/PersonalLifeOS/lifeos"

if [[ ! -f "$APP/manage.py" ]]; then
  echo "Missing Django manage.py: $APP/manage.py"
  exit 1
fi

cd "$APP"
if [[ -x "venv/bin/python" ]]; then
  venv/bin/python manage.py check
elif [[ -x ".venv/bin/python" ]]; then
  .venv/bin/python manage.py check
else
  python3 manage.py check
fi
