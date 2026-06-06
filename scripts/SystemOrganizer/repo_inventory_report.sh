#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
INVENTORY="$REPO_ROOT/config/repo_inventory.json"

if [[ ! -f "$INVENTORY" ]]; then
  "$SCRIPT_DIR/refresh_repo_inventory.sh"
fi

/usr/bin/env python3 - "$INVENTORY" <<'PY'
import json
import sys
from collections import defaultdict

with open(sys.argv[1], "r", encoding="utf-8") as f:
    data = json.load(f)

print("Repo Inventory")
print(f"Generated: {data.get('generated_at', 'unknown')}")
print()

groups = defaultdict(list)
for repo in data.get("repos", []):
    groups[repo.get("group", "unknown")].append(repo)

for group in sorted(groups):
    print(f"== {group} ==")
    for repo in sorted(groups[group], key=lambda r: r.get("name", "").lower()):
        active = "active" if repo.get("active_project") else "inventory"
        dirty = repo.get("git", {}).get("dirty_count", 0)
        hint = repo.get("validation_hint") or "none"
        print(f"- {repo.get('name')} [{active}] dirty={dirty} check={hint}")
    print()
PY
