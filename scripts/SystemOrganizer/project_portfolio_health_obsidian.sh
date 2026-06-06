#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
export SYSORG_WRITE_OBSIDIAN=1

"$SCRIPT_DIR/project_portfolio_health.sh"

