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

# df of / is a sealed System snapshot — misleading for free space.
# Real capacity comes from the APFS container.
DF_H="$(/bin/df -h / 2>/dev/null || echo "(df unavailable)")"
DF_LINE="$(/bin/df -P / | /usr/bin/awk 'NR==2 {print $2, $3, $4, $5}')"
DISK_BLOCKS="$(echo "$DF_LINE" | /usr/bin/awk '{print $1}')"
DISK_USED_B="$(echo "$DF_LINE" | /usr/bin/awk '{print $2}')"
DISK_AVAIL_B="$(echo "$DF_LINE" | /usr/bin/awk '{print $3}')"
DISK_CAP="$(echo "$DF_LINE" | /usr/bin/awk '{gsub(/%/,"",$4); print $4+0}')"
DISK_TOTAL_GIB="$(/usr/bin/awk -v b="$DISK_BLOCKS" 'BEGIN { printf "%.0f", (b * 512) / (1024*1024*1024) }')"
DISK_USED_GIB="$(/usr/bin/awk -v b="$DISK_USED_B" 'BEGIN { printf "%.0f", (b * 512) / (1024*1024*1024) }')"
DISK_FREE_GIB="$(/usr/bin/awk -v b="$DISK_AVAIL_B" 'BEGIN { printf "%.0f", (b * 512) / (1024*1024*1024) }')"

APFS_LIST="$(/usr/sbin/diskutil apfs list 2>/dev/null || echo "(diskutil apfs list unavailable)")"
# First container's real usage (boot disk on Apple silicon / modern Macs)
CONTAINER_USED_PCT="$(echo "$APFS_LIST" | /usr/bin/sed -nE 's/.*Capacity In Use By Volumes:.*\(([0-9.]+)% used\).*/\1/p' | /usr/bin/head -1)"
CONTAINER_FREE_GIB="$(echo "$APFS_LIST" | /usr/bin/sed -nE 's/.*Capacity Not Allocated:.*\(([0-9.]+) GB\).*/\1/p' | /usr/bin/head -1)"
CONTAINER_USED_GIB="$(echo "$APFS_LIST" | /usr/bin/sed -nE 's/.*Capacity In Use By Volumes:.*\(([0-9.]+) GB\).*/\1/p' | /usr/bin/head -1)"
CONTAINER_TOTAL_GIB="$(echo "$APFS_LIST" | /usr/bin/sed -nE 's/.*Size \(Capacity Ceiling\):.*\(([0-9.]+) GB\).*/\1/p' | /usr/bin/head -1)"
# Integer % for comparisons (88.0 -> 88)
CONTAINER_USED_INT="$(/usr/bin/awk -v p="${CONTAINER_USED_PCT:-0}" 'BEGIN { printf "%.0f", p+0 }')"

DISKUTIL_ROOT="$(/usr/sbin/diskutil info / 2>/dev/null | /usr/bin/awk '
  /Device Identifier:|Volume Name:|Mount Point:|File System Personality:|Disk Size:|Volume Used Space:|Container Total Space:|Container Free Space:|Solid State:|APFS Container:|APFS Physical Store:|This disk is an APFS Volume Snapshot/ { print }
' || echo "(diskutil unavailable)")"

DATA_VOL_GB="$(echo "$APFS_LIST" | /usr/bin/awk '
  /APFS Volume Disk \(Role\):.*\(Data\)/ { d=1; next }
  d && /Capacity Consumed:/ {
    if (match($0, /\(([0-9.]+) GB\)/)) {
      print substr($0, RSTART + 1, RLENGTH - 5)
      exit
    }
  }
')"

TM_SNAPSHOTS="$(/usr/bin/tmutil listlocalsnapshots / 2>/dev/null || echo "(tmutil unavailable)")"

LOAD="$(/usr/bin/uptime | /usr/bin/sed -E 's/.*load averages?: //')"
LOAD1="$(echo "$LOAD" | /usr/bin/awk '{print $1+0}')"
NCPU="$(/usr/sbin/sysctl -n hw.ncpu 2>/dev/null || echo 1)"

TOP_CPU="$(/bin/ps -arcwwwxo pid=,pcpu=,pmem=,comm= 2>/dev/null | /usr/bin/head -8 || true)"
TOP_MEM="$(/bin/ps -amcwwwxo pid=,pmem=,pcpu=,comm= 2>/dev/null | /usr/bin/head -8 || true)"

MEM_PRESSURE="$(/usr/bin/memory_pressure 2>/dev/null || echo "(memory_pressure unavailable)")"
MEM_FREE_PCT="$(echo "$MEM_PRESSURE" | /usr/bin/awk -F': ' '/System-wide memory free percentage/ { gsub(/%/,"",$NF); print $NF+0; exit }')"
THERM="$(/usr/bin/pmset -g therm 2>/dev/null || echo "(pmset therm unavailable)")"
BATT="$(/usr/bin/pmset -g batt 2>/dev/null || echo "(pmset batt unavailable)")"

# Stream logs to a temp file — avoid holding tens of thousands of lines in RAM.
LOG_TMP="$(/usr/bin/mktemp -t so_sys_errs)"
FILTERED_TMP="$(/usr/bin/mktemp -t so_sys_errs_f)"
trap '/bin/rm -f "$LOG_TMP" "$FILTERED_TMP"' EXIT
{ /usr/bin/log show --last 15m --style compact --predicate 'messageType == error OR messageType == fault' 2>/dev/null || true; } > "$LOG_TMP"
SANDBOX_COUNT="$(/usr/bin/grep -c 'Sandbox:.*deny(' "$LOG_TMP" 2>/dev/null || true)"
SANDBOX_COUNT="${SANDBOX_COUNT:-0}"
FAULT_COUNT="$(/usr/bin/awk '$3 == "F" { n++ } END { print n+0 }' "$LOG_TMP")"
# Drop sandbox denials + chronically noisy prefs/sharing chatter on macOS betas
/usr/bin/grep -Ev 'Sandbox:.*deny\(|cfprefsd.*Couldn.t open|Unable to decrypt activity level|No BeaconStoreActor' "$LOG_TMP" > "$FILTERED_TMP" || true
ERR_COUNT="$(/usr/bin/wc -l < "$FILTERED_TMP" | /usr/bin/tr -d ' ')"
ERR_COUNT="${ERR_COUNT:-0}"
ERR_SAMPLE="$(/usr/bin/tail -40 "$FILTERED_TMP")"
ERR_BY_PROCESS="$(
  /usr/bin/awk '
    $3 ~ /^[EF]$/ {
      p = $4
      sub(/\[.*/, "", p)
      if (p != "") c[p]++
    }
    END {
      for (p in c) printf "%6d  %s\n", c[p], p
    }
  ' "$FILTERED_TMP" | /usr/bin/sort -rn | /usr/bin/head -12
)"
RAW_LINE_COUNT="$(/usr/bin/wc -l < "$LOG_TMP" | /usr/bin/tr -d ' ')"
RAW_LINE_COUNT="${RAW_LINE_COUNT:-0}"

WARNINGS=()
OK_NOTES=()

if /usr/bin/awk -v l="$LOAD1" -v n="$NCPU" 'BEGIN { exit !(l > n) }'; then
  WARNINGS+=("Load ${LOAD1} is above CPU count (${NCPU}) — machine is busy.")
else
  OK_NOTES+=("Load ${LOAD1} is within CPU capacity (${NCPU} cores).")
fi

# Prefer APFS container % (truth); sealed / df is only a footnote.
if [[ -n "${CONTAINER_USED_PCT}" ]]; then
  if (( CONTAINER_USED_INT >= 90 )); then
    WARNINGS+=("APFS container critically full (${CONTAINER_USED_PCT}% used, ${CONTAINER_FREE_GIB:-?} GB free).")
  elif (( CONTAINER_USED_INT >= 80 )); then
    WARNINGS+=("APFS container getting full (${CONTAINER_USED_PCT}% used, ${CONTAINER_FREE_GIB:-?} GB free). df / looks low because / is a sealed System snapshot.")
  else
    OK_NOTES+=("APFS container OK (${CONTAINER_USED_PCT}% used, ${CONTAINER_FREE_GIB:-?} GB free of ${CONTAINER_TOTAL_GIB:-?} GB).")
  fi
else
  if (( DISK_CAP >= 90 )); then
    WARNINGS+=("Disk critically full (${DISK_CAP}% used, ${DISK_FREE_GIB} GiB free).")
  elif (( DISK_CAP >= 80 )); then
    WARNINGS+=("Disk getting full (${DISK_CAP}% used, ${DISK_FREE_GIB} GiB free).")
  else
    OK_NOTES+=("Disk OK via df (${DISK_CAP}% used) — container stats unavailable.")
  fi
fi

if [[ -n "${DATA_VOL_GB}" ]]; then
  OK_NOTES+=("Data volume consuming ~${DATA_VOL_GB} GB (Macintosh HD - Data).")
fi

if [[ "${SWAPOUTS}" != "0" ]]; then
  WARNINGS+=("Swap activity detected (swapouts=${SWAPOUTS}) — memory pressure.")
else
  OK_NOTES+=("No swap outs — memory pressure is manageable.")
fi

if [[ -n "${MEM_FREE_PCT}" ]]; then
  if /usr/bin/awk -v p="$MEM_FREE_PCT" 'BEGIN { exit !(p < 10) }'; then
    WARNINGS+=("Memory free percentage critically low (${MEM_FREE_PCT}%).")
  elif /usr/bin/awk -v p="$MEM_FREE_PCT" 'BEGIN { exit !(p < 20) }'; then
    WARNINGS+=("Memory free percentage low (${MEM_FREE_PCT}%).")
  else
    OK_NOTES+=("Memory free percentage OK (${MEM_FREE_PCT}%).")
  fi
fi

if echo "$THERM" | /usr/bin/grep -Eqi 'No thermal warning level has been recorded'; then
  OK_NOTES+=("No thermal or CPU power warnings recorded.")
elif [[ "$THERM" == *"(pmset therm unavailable)"* ]]; then
  :
else
  WARNINGS+=("Thermal/power pressure reported by pmset.")
fi

BATT_PCT="$(echo "$BATT" | /usr/bin/awk '/InternalBattery/ {
  for (i = 1; i <= NF; i++) {
    if ($i ~ /^[0-9]+%;?$/) { gsub(/[^0-9]/, "", $i); print $i + 0; exit }
  }
}')"
if echo "$BATT" | /usr/bin/grep -qi 'discharging' && [[ -n "$BATT_PCT" ]]; then
  if (( BATT_PCT <= 10 )); then
    WARNINGS+=("Battery critically low (${BATT_PCT}%, discharging).")
  elif (( BATT_PCT <= 20 )); then
    WARNINGS+=("Battery low (${BATT_PCT}%, discharging).")
  fi
elif echo "$BATT" | /usr/bin/grep -Eqi "AC Power|charged|charging"; then
  OK_NOTES+=("Power: on AC or battery charged.")
fi

OK_NOTES+=("Logs last 15m: ${RAW_LINE_COUNT} raw error/fault (${FAULT_COUNT} faults, ${SANDBOX_COUNT} sandbox denials); ${ERR_COUNT} after filter — see summary.")

TOP_CPU_NAME="$(echo "$TOP_CPU" | /usr/bin/head -1 | /usr/bin/awk '{for(i=4;i<=NF;i++) printf "%s%s", $i, (i<NF?" ":""); print ""}')"
TOP_CPU_PCT="$(echo "$TOP_CPU" | /usr/bin/head -1 | /usr/bin/awk '{print $2+0}')"
if /usr/bin/awk -v p="$TOP_CPU_PCT" 'BEGIN { exit !(p >= 15) }'; then
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

  echo "── APFS Storage (real capacity) ──────────────────"
  if [[ -n "${CONTAINER_USED_PCT}" ]]; then
    echo "  Container: ${CONTAINER_USED_GIB:-?} GB used / ${CONTAINER_TOTAL_GIB:-?} GB (${CONTAINER_USED_PCT}% used) — ${CONTAINER_FREE_GIB:-?} GB free"
  else
    echo "  Container: (could not parse)"
  fi
  if [[ -n "${DATA_VOL_GB}" ]]; then
    echo "  Data volume: ~${DATA_VOL_GB} GB (Macintosh HD - Data)"
  fi
  echo "  Sealed System mount df / (misleading alone):"
  echo "$DF_H" | /usr/bin/sed 's/^/    /'
  echo "  (${DISK_USED_GIB} GiB / ${DISK_TOTAL_GIB} GiB shown = snapshot, not whole disk)"
  echo
  echo "  Root volume (diskutil info /):"
  echo "$DISKUTIL_ROOT" | /usr/bin/sed 's/^/    /'
  echo
  echo "  APFS volumes (diskutil apfs list, first container):"
  echo "$APFS_LIST" | /usr/bin/awk '
    BEGIN { show=0; n=0 }
    /^[+|]-- Container disk/ { if (n++) exit; show=1 }
    show { print }
  ' | /usr/bin/sed 's/^/    /'
  echo
  echo "  Local snapshots (tmutil):"
  echo "$TM_SNAPSHOTS" | /usr/bin/sed 's/^/    /'
  echo

  echo "── Memory (approx GiB) ───────────────────────────"
  echo "  Free:       ${FREE_GIB}"
  echo "  Active:     ${ACTIVE_GIB}"
  echo "  Inactive:   ${INACTIVE_GIB}"
  echo "  Wired:      ${WIRED_GIB}"
  echo "  Compressed: ${COMP_GIB}"
  echo "  Swapins:    ${SWAPINS}   Swapouts: ${SWAPOUTS}"
  echo

  echo "── Memory Pressure ───────────────────────────────"
  echo "$MEM_PRESSURE" | /usr/bin/sed 's/^/  /'
  echo

  echo "── Thermal State ─────────────────────────────────"
  echo "$THERM" | /usr/bin/sed 's/^/  /'
  echo

  echo "── Power and Battery ─────────────────────────────"
  echo "$BATT" | /usr/bin/sed 's/^/  /'
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

  echo "── Recent System Errors (last 15m) ───────────────"
  echo "  Raw error/fault lines: ${RAW_LINE_COUNT}"
  echo "  Sandbox denials ignored: ${SANDBOX_COUNT}"
  echo "  Fault (F) lines: ${FAULT_COUNT}"
  echo "  After noise filter: ${ERR_COUNT}"
  if [[ -n "${ERR_BY_PROCESS}" ]]; then
    echo "  Top processes (filtered):"
    echo "$ERR_BY_PROCESS" | /usr/bin/sed 's/^/    /'
    echo
  fi
  if [[ -n "${ERR_SAMPLE}" ]]; then
    echo "  Last filtered lines (up to 40):"
    echo "$ERR_SAMPLE" | /usr/bin/sed 's/^/    /'
  else
    echo "  (none after filtering)"
  fi
  echo

  echo "── Notes ─────────────────────────────────────────"
  echo "  Generated by scripts/SystemOrganizer/daily_system_report.sh"
  echo "  Disk health uses APFS container %, not sealed df /."
} > "$REPORT_FILE"

echo "Saved system report: $REPORT_FILE"
echo "Verdict: $VERDICT"

if (( ${#WS_HINTS[@]} > 0 )) && [[ "${SKIP_NATIVE_ALERT:-0}" != "1" ]]; then
  /usr/bin/osascript - "$WS_PCT" "$REPORT_FILE" <<'APPLESCRIPT'
on run argv
  set pct to item 1 of argv
  set reportPath to item 2 of argv
  display alert "WindowServer high CPU" message "WindowServer is using " & pct & "% CPU." & return & return & "The display compositor is busy (not a crash). Close unused Cursor/browser windows, enable Reduce motion, or check screen sharing." & return & return & "Report saved to:" & return & reportPath as warning buttons {"OK"} default button "OK"
end run
APPLESCRIPT
fi
