#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

/usr/bin/env python3 "$SCRIPT_DIR/configure_system_organizer.py"
