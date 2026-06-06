#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

/usr/bin/env python3 "$SCRIPT_DIR/refresh_repo_inventory.py"
