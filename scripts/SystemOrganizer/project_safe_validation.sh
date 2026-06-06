#!/bin/zsh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PROJECTS_MANIFEST="${SYSORG_PROJECTS_MANIFEST:-$REPO_ROOT/config/projects.json}"
export SYSORG_PROJECTS_MANIFEST="$PROJECTS_MANIFEST"
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:/usr/local/bin:${PATH:-}"
failures=0

run_step_cmd() {
  local name="$1"
  local project_path="$2"
  local cmd="$3"

  printf '\n== %s ==\n' "$name"

  if [[ ! -d "$project_path" ]]; then
    echo "FAILED: missing project path: $project_path"
    failures=$((failures + 1))
    return
  fi

  (
    cd "$project_path"
    /bin/zsh -lc "$cmd"
  )
  local exit_status=$?
  if [[ "$exit_status" -ne 0 ]]; then
    echo "FAILED: $name exited with $exit_status"
    failures=$((failures + 1))
  else
    echo "PASSED: $name"
  fi
}

export TIMEOUT_SECONDS=300

run_validation() {
  local ran_any=0
  while IFS=$'\t' read -r pid name path validate_cmd daily_cmd daily_requires_env tags_csv; do
    if [[ -z "$validate_cmd" ]]; then
      continue
    fi
    ran_any=1
    run_step_cmd "$name" "$path" "$validate_cmd"
  done < <(/usr/bin/env python3 "$SCRIPT_DIR/read_projects.py" 2>/dev/null)

  if [[ "$ran_any" -eq 0 ]]; then
    echo "No validate_cmd entries found. Check manifest: $PROJECTS_MANIFEST"
    return 1
  fi
}

if [[ "${SYSORG_WRITE_OBSIDIAN:-0}" == "1" ]]; then
  tmp="$(/usr/bin/mktemp -t sysorg_safe_validation.XXXXXX)"
  trap 'rm -f "$tmp"' EXIT
  {
    echo "# Project Safe Validation"
    echo
    echo "Generated: $(/bin/date)"
    echo "Manifest: $PROJECTS_MANIFEST"
    echo
    run_validation
  } | /usr/bin/tee "$tmp"

  note_path="$("$SCRIPT_DIR/write_obsidian_note.sh" \
    --title "Project Safe Validation" \
    --folder "System Organizer/Reports" \
    --content "$(/bin/cat "$tmp")")"
  echo
  echo "Saved Obsidian note: $note_path"
else
  run_validation
fi

if [[ "$failures" -eq 0 ]]; then
  printf '\nAll safe project validation checks completed.\n'
else
  printf '\nSafe project validation completed with %s failure(s).\n' "$failures"
  exit 1
fi
