#!/bin/zsh
set -euo pipefail

REPORT_DIR="${HOME}/Desktop/System_Reports"
STAMP="$(/bin/date +%F)"
REPORT_FILE="$REPORT_DIR/${STAMP}_system_report.txt"
PAGE_SIZE="$(/usr/bin/pagesize 2>/dev/null || echo 16384)"

mkdir -p "$REPORT_DIR"

pages_to_gib() {
  /usr/bin/awk -v p="${1:-0}" -v s="$PAGE_SIZE" 'BEGIN { printf "%.2f", (p * s) / (1024*1024*1024) }'
}

vm_field() {
  /usr/bin/vm_stat | /usr/bin/awk -v key="$1" '
    index($0, key ":") == 1 {
      gsub(/\./, "", $NF)
      print $NF + 0
      exit
    }'
}

FREE_PAGES="$(vm_field "Pages free")"
ACTIVE_PAGES="$(vm_field "Pages active")"
INACTIVE_PAGES="$(vm_field "Pages inactive")"
WIRED_PAGES="$(vm_field "Pages wired down")"
COMPRESSED_PAGES="$(vm_field "Pages occupied by compressor")"
SWAPINS="$(vm_field "Swapins")"
SWAPOUTS="$(vm_field "Swapouts")"

FREE_GIB="$(pages_to_gib "$FREE_PAGES")"
ACTIVE_GIB="$(pages_to_gib "$ACTIVE_PAGES")"
INACTIVE_GIB="$(pages_to_gib "$INACTIVE_PAGES")"
WIRED_GIB="$(pages_to_gib "$WIRED_PAGES")"
COMP_GIB="$(pages_to_gib "$COMPRESSED_PAGES")"

# df -P: 512-byte blocks on macOS
DF_LINE="$(/bin/df -P / | /usr/bin/awk 'NR==2 {print $2, $3, $4, $5}')"
DISK_BLOCKS="$(echo "$DF_LINE" | /usr/bin/awk '{print $1}')"
DISK_USED_B="$(echo "$DF_LINE" | /usr/bin/awk '{print $2}')"
DISK_AVAIL_B="$(echo "$DF_LINE" | /usr/bin/awk '{print $3}')"
DISK_CAP="$(echo "$DF_LINE" | /usr/bin/awk '{gsub(/%/,"",$4); print $4+0}')"

DISK_TOTAL_GIB="$(/usr/bin/awk -v b="$DISK_BLOCKS" 'BEGIN { printf "%.0f", (b * 512) / (1024*1024*1024) }')"
DISK_USED_GIB="$(/usr/bin/awk -v b="$DISK_USED_B" 'BEGIN { printf "%.0f", (b * 512) / (1024*1024*1024) }')"
DISK_FREE_GIB="$(/usr/bin/awk -v b="$DISK_AVAIL_B" 'BEGIN { printf "%.0f", (b * 512) / (1024*1024*1024) }')"

# macOS uptime: "load averages: 1.2 1.3 1.4" (spaces, not commas)
LOAD="$(/usr/bin/uptime | /usr/bin/sed -E 's/.*load averages?: //')"
LOAD1="$(echo "$LOAD" | /usr/bin/awk '{print $1+0}')"
NCPU="$(/usr/sbin/sysctl -n hw.ncpu 2>/dev/null || echo 1)"

TOP_CPU="$(/bin/ps -arcwwwxo pid=,pcpu=,pmem=,comm= 2>/dev/null | /usr/bin/head -8 || true)"
TOP_MEM="$(/bin/ps -amcwwwxo pid=,pmem=,pcpu=,comm= 2>/dev/null | /usr/bin/head -8 || true)"

WARNINGS=()
OK_NOTES=()

if /usr/bin/awk -v l="$LOAD1" -v n="$NCPU" 'BEGIN { exit !(l > n) }'; then
  WARNINGS+=("Load ${LOAD1} is above CPU count (${NCPU}) — machine is busy.")
else
  OK_NOTES+=("Load ${LOAD1} is within CPU capacity (${NCPU} cores).")
fi

if (( DISK_CAP >= 90 )); then
  WARNINGS+=("Disk critically full (${DISK_CAP}% used, ${DISK_FREE_GIB} GiB free).")
elif (( DISK_CAP >= 80 )); then
  WARNINGS+=("Disk getting full (${DISK_CAP}% used, ${DISK_FREE_GIB} GiB free).")
else
  OK_NOTES+=("Disk OK (${DISK_CAP}% used, ${DISK_FREE_GIB} GiB free of ${DISK_TOTAL_GIB} GiB).")
fi

if [[ "${SWAPOUTS}" != "0" ]]; then
  WARNINGS+=("Swap activity detected (swapouts=${SWAPOUTS}) — memory pressure.")
else
  OK_NOTES+=("No swap outs — memory pressure is manageable.")
fi

TOP_CPU_NAME="$(echo "$TOP_CPU" | /usr/bin/head -1 | /usr/bin/awk '{for(i=4;i<=NF;i++) printf "%s%s", $i, (i<NF?" ":""); print ""}')"
TOP_CPU_PCT="$(echo "$TOP_CPU" | /usr/bin/head -1 | /usr/bin/awk '{print $2+0}')"
if /usr/bin/awk -v p="$TOP_CPU_PCT" 'BEGIN { exit !(p >= 15) }'; then
  # WindowServer gets its own section below — avoid a duplicate generic line
  if [[ "$TOP_CPU_NAME" != *WindowServer* ]]; then
    WARNINGS+=("High CPU: ${TOP_CPU_NAME} at ${TOP_CPU_PCT}%.")
  fi
fi

WS_LINE="$(echo "$TOP_CPU" | /usr/bin/awk '/WindowServer/ {print; exit}')"
WS_PCT="0"
WS_HINTS=()
if [[ -n "$WS_LINE" ]]; then
  WS_PCT="$(echo "$WS_LINE" | /usr/bin/awk '{print $2+0}')"
  if /usr/bin/awk -v p="$WS_PCT" 'BEGIN { exit !(p >= 15) }'; then
    WARNINGS+=("WindowServer using ${WS_PCT}% CPU — display compositor is busy (not a standalone crash).")
    WS_HINTS+=(
      "Close unused Cursor / browser / ChatGPT windows (Retina redraw is expensive)."
      "System Settings → Accessibility → Display: enable Reduce motion (and Reduce transparency)."
      "Stop screen sharing / recording if active; unplug external displays to test."
      "Quit menu-bar agents one-by-one (e.g. Logitech) if it stays high while idle."
      "Logout/login or reboot if still high — common on macOS betas."
    )
  fi
fi

SO_LINE="$(echo "$TOP_CPU" | /usr/bin/awk '/SystemOrganizer/ {print; exit}')"
if [[ -n "$SO_LINE" ]]; then
  SO_PCT="$(echo "$SO_LINE" | /usr/bin/awk '{print $2+0}')"
  if /usr/bin/awk -v p="$SO_PCT" 'BEGIN { exit !(p >= 10) }'; then
    WARNINGS+=("SystemOrganizer using ${SO_PCT}% CPU — consider closing window or slowing metrics polling.")
  fi
fi

if (( ${#WARNINGS[@]} == 0 )); then
  VERDICT="HEALTHY"
else
  VERDICT="ATTENTION (${#WARNINGS[@]} warning(s))"
fi

UPTIME_SHORT="$(/usr/bin/uptime | /usr/bin/sed -E 's/^[[:space:]]*[0-9:]+[[:space:]]+up[[:space:]]+//; s/,[[:space:]]*[0-9]+[[:space:]]+users?.*//')"

{
  echo "══════════════════════════════════════════════════"
  echo " System Report — $(/bin/date '+%Y-%m-%d %H:%M %Z')"
  echo "══════════════════════════════════════════════════"
  echo
  echo "VERDICT: $VERDICT"
  echo "Host:    $(/bin/hostname -s)"
  echo "macOS:   $(/usr/bin/sw_vers -productVersion) ($(/usr/bin/sw_vers -buildVersion))"
  echo "Uptime:  $UPTIME_SHORT"
  echo "CPUs:    $NCPU"
  echo "Load:    $LOAD"
  echo

  if (( ${#WARNINGS[@]} > 0 )); then
    echo "── Warnings ──────────────────────────────────────"
    for w in "${WARNINGS[@]}"; do
      echo "  ! $w"
    done
    echo
  fi

  if (( ${#OK_NOTES[@]} > 0 )); then
    echo "── OK ────────────────────────────────────────────"
    for n in "${OK_NOTES[@]}"; do
      echo "  ✓ $n"
    done
    echo
  fi

  if (( ${#WS_HINTS[@]} > 0 )); then
    echo "── WindowServer — what it means & how to fix ─────"
    echo "  WindowServer composites every pixel on screen."
    echo "  High CPU = constant redraw (apps/displays), not a"
    echo "  broken system by itself. Try in order:"
    i=1
    for h in "${WS_HINTS[@]}"; do
      echo "  ${i}. $h"
      i=$((i + 1))
    done
    echo
  fi

  echo "── Disk (/) ──────────────────────────────────────"
  echo "  Used ${DISK_USED_GIB} GiB / ${DISK_TOTAL_GIB} GiB (${DISK_CAP}%) — ${DISK_FREE_GIB} GiB free"
  echo

  echo "── Memory (approx GiB) ───────────────────────────"
  echo "  Free:       ${FREE_GIB}"
  echo "  Active:     ${ACTIVE_GIB}"
  echo "  Inactive:   ${INACTIVE_GIB}"
  echo "  Wired:      ${WIRED_GIB}"
  echo "  Compressed: ${COMP_GIB}"
  echo "  Swapins:    ${SWAPINS}   Swapouts: ${SWAPOUTS}"
  echo

  echo "── Top CPU ───────────────────────────────────────"
  printf "  %-7s %6s %5s  %s\n" "PID" "%CPU" "%MEM" "Process"
  echo "$TOP_CPU" | while read -r pid cpu mem rest; do
    [[ -z "${pid:-}" ]] && continue
    printf "  %-7s %6s %5s  %s\n" "$pid" "$cpu" "$mem" "$rest"
  done
  echo

  echo "── Top Memory ────────────────────────────────────"
  printf "  %-7s %5s %6s  %s\n" "PID" "%MEM" "%CPU" "Process"
  echo "$TOP_MEM" | while read -r pid mem cpu rest; do
    [[ -z "${pid:-}" ]] && continue
    printf "  %-7s %5s %6s  %s\n" "$pid" "$mem" "$cpu" "$rest"
  done
  echo

  echo "── Notes ─────────────────────────────────────────"
  echo "  Generated by scripts/SystemOrganizer/daily_system_report.sh"
} > "$REPORT_FILE"

echo "Saved system report: $REPORT_FILE"
echo "Verdict: $VERDICT"

if (( ${#WS_HINTS[@]} > 0 )); then
  /usr/bin/osascript - "$WS_PCT" "$REPORT_FILE" <<'APPLESCRIPT'
on run argv
  set pct to item 1 of argv
  set reportPath to item 2 of argv
  display alert "WindowServer high CPU" message "WindowServer is using " & pct & "% CPU." & return & return & "The display compositor is busy (not a crash). Close unused Cursor/browser windows, enable Reduce motion, or check screen sharing." & return & return & "Report saved to:" & return & reportPath as warning buttons {"OK"} default button "OK"
end run
APPLESCRIPT
fi
