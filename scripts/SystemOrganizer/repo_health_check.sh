#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

"$SCRIPT_DIR/refresh_repo_inventory.sh" >/dev/null
/usr/bin/env python3 "$SCRIPT_DIR/repo_health_check.py"
