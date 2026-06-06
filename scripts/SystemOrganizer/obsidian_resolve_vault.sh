#!/bin/zsh
set -euo pipefail

# Resolve an Obsidian vault path using this precedence:
#  1) OBSIDIAN_VAULT_PATH env var
#  2) Default vault from ~/Library/Application Support/SystemOrganizer/obsidian_vaults.json
#  3) Fallback: $HOME/Documents/OBSIDIAN_VAULTS
#
# Prints the resolved absolute path to stdout.

resolve_from_json() {
  local json_file="$1"
  if [[ ! -f "$json_file" ]]; then
    return 1
  fi

  # NOTE: Uses python3 stdlib only (no jq dependency).
  /usr/bin/env python3 - "$json_file" <<'PY'
import json, sys, os
path = sys.argv[1]
try:
    with open(path, "r", encoding="utf-8") as f:
        vaults = json.load(f)
except Exception:
    sys.exit(2)
if not isinstance(vaults, list):
    sys.exit(2)
default = None
for v in vaults:
    if isinstance(v, dict) and v.get("isDefault") is True and v.get("path"):
        default = v.get("path")
        break
if not default:
    sys.exit(3)
default = str(default).replace("$HOME", os.path.expanduser("~"))
default = os.path.expanduser(default)
print(default)
PY
}

if [[ -n "${OBSIDIAN_VAULT_PATH:-}" ]]; then
  echo "${OBSIDIAN_VAULT_PATH/#\~/$HOME}"
  exit 0
fi

APP_SUPPORT="$HOME/Library/Application Support/SystemOrganizer"
VAULTS_JSON="$APP_SUPPORT/obsidian_vaults.json"

if vault_path="$(resolve_from_json "$VAULTS_JSON" 2>/dev/null)"; then
  echo "${vault_path/#\~/$HOME}"
  exit 0
fi

echo "$HOME/Documents/OBSIDIAN_VAULTS"

