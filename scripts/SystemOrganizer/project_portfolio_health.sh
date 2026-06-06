#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PROJECTS_MANIFEST="${SYSORG_PROJECTS_MANIFEST:-$REPO_ROOT/config/projects.json}"
export SYSORG_PROJECTS_MANIFEST="$PROJECTS_MANIFEST"
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:/usr/local/bin:${PATH:-}"

command_exists() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1 && return 0
  [[ -x "/opt/homebrew/bin/$cmd" ]] && return 0
  [[ -x "/usr/local/bin/$cmd" ]] && return 0
  [[ -x "/usr/bin/$cmd" ]] && return 0
  return 1
}

section() {
  printf '\n== %s ==\n' "$1"
}

git_summary() {
  local project="$1"

  if [[ ! -d "$project/.git" ]]; then
    echo "Git: not a repository"
    return
  fi

  local branch
  branch="$(/usr/bin/git -C "$project" rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"

  local dirty_count
  dirty_count="$(/usr/bin/git -C "$project" status --porcelain 2>/dev/null | /usr/bin/wc -l | /usr/bin/tr -d ' ')"

  local upstream
  upstream="$(/usr/bin/git -C "$project" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || true)"

  echo "Git: branch=$branch dirty=$dirty_count upstream=${upstream:-none}"
}

python_summary() {
  local project="$1"

  if [[ -f "$project/pyproject.toml" || -f "$project/requirements.txt" || -f "$project/manage.py" ]]; then
    if [[ -x "$project/.venv/bin/python" ]]; then
      echo "Python: .venv present"
      "$project/.venv/bin/python" --version 2>&1
    elif [[ -x "/usr/bin/python3" ]]; then
      echo "Python: no project .venv, system python available"
      /usr/bin/python3 --version 2>&1
    elif [[ -x "/opt/homebrew/bin/python3" ]]; then
      echo "Python: no project .venv, system python available"
      /opt/homebrew/bin/python3 --version 2>&1
    elif command_exists python3; then
      echo "Python: no project .venv, system python available"
      python3 --version 2>&1
    else
      echo "Python: missing python3"
    fi
  fi
}

node_summary() {
  local package_file="$1"
  local package_dir
  package_dir="$(/usr/bin/dirname "$package_file")"

  if [[ ! -f "$package_file" ]]; then
    return
  fi

  local name
  name="$(/usr/bin/basename "$package_dir")"
  if [[ "$package_dir" == "$(/usr/bin/dirname "$package_dir")" ]]; then
    name="$(/usr/bin/basename "$(/usr/bin/dirname "$package_file")")"
  fi

  if ! command_exists node; then
    echo "Node ($name): missing node"
    return
  fi

  if [[ -d "$package_dir/node_modules" ]]; then
    echo "Node ($name): node_modules present"
  else
    echo "Node ($name): node_modules missing"
  fi

  if command_exists npm; then
    local scripts
    local nodebin="node"
    if ! command -v node >/dev/null 2>&1; then
      [[ -x "/opt/homebrew/bin/node" ]] && nodebin="/opt/homebrew/bin/node"
      [[ -x "/usr/local/bin/node" ]] && nodebin="/usr/local/bin/node"
      [[ -x "/usr/bin/node" ]] && nodebin="/usr/bin/node"
    fi
    scripts="$("$nodebin" -e 'const p=require(process.argv[1]); console.log(Object.keys(p.scripts||{}).join(","))' "$package_file" 2>/dev/null || true)"
    echo "Node ($name): scripts=${scripts:-none}"
  else
    echo "Node ($name): missing npm"
  fi
}

django_summary() {
  local project="$1"

  if [[ -f "$project/manage.py" ]]; then
    echo "Django: manage.py present"
  fi

  local nested
  for nested in "$project"/*/manage.py(N) "$project"/.*/*/manage.py(N); do
    [[ -f "$nested" ]] || continue
    echo "Django: nested app at $(/usr/bin/dirname "$nested")"
  done
}

run_report() {
  local projects=()
  while IFS=$'\t' read -r pid name path validate_cmd daily_cmd daily_requires_env tags_csv; do
    projects+=("$path")
  done < <(/usr/bin/env python3 "$SCRIPT_DIR/read_projects.py" 2>/dev/null)

  if [[ "${#projects[@]}" -eq 0 ]]; then
    echo "No projects found. Check manifest: $PROJECTS_MANIFEST"
    return 1
  fi

  for project in "${projects[@]}"; do
    section "$(/usr/bin/basename "$project")"

    if [[ ! -d "$project" ]]; then
      echo "Missing project path: $project"
      continue
    fi

    git_summary "$project"
    python_summary "$project"
    django_summary "$project"

    while IFS= read -r package_file; do
      node_summary "$package_file"
    done < <(
      /usr/bin/find "$project" -maxdepth 3 \
        \( -name node_modules -o -name .git -o -name '.codex-predeploy-*' -o -name .pytest_cache \) -prune \
        -o -name package.json -print | /usr/bin/sort -u
    )
  done

  section "Recommended System Organizer Automations"
  /bin/cat <<'REPORT'
fulofilo-analytics:
  make automation-validate-data-integrity
  make automation-run-daily

giovannini-finance:
  cd finance-tracker && npm run build
  cd Personal_Tracker_macros && uvicorn app.main:app --port 8012

GMC:
  npm run build
  cd .GMC_TUI_DJANGO && python manage.py check

PersonalLifeOS:
  python manage.py check
REPORT
}

if [[ "${SYSORG_WRITE_OBSIDIAN:-0}" == "1" ]]; then
  tmp="$(/usr/bin/mktemp -t sysorg_portfolio_health.XXXXXX)"
  trap 'rm -f "$tmp"' EXIT
  {
    echo "# Project Portfolio Health"
    echo
    echo "Generated: $(/bin/date)"
    echo "Manifest: $PROJECTS_MANIFEST"
    echo
    run_report
  } | /usr/bin/tee "$tmp"

  note_path="$("$SCRIPT_DIR/write_obsidian_note.sh" \
    --title "Project Portfolio Health" \
    --folder "System Organizer/Reports" \
    --content "$(/bin/cat "$tmp")")"
  echo
  echo "Saved Obsidian note: $note_path"
else
  run_report
fi
