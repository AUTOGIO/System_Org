#!/bin/zsh
set -euo pipefail

REPORT_DIR="/Users/giovannini_nuovo/Desktop/System_Reports"
REPORT_FILE="$REPORT_DIR/$(/bin/date +%F)_system_report.txt"

mkdir -p "$REPORT_DIR"

{
  echo "System Report"
  echo "Generated: $(/bin/date)"
  echo
  echo "Host:"
  /bin/hostname
  echo
  echo "macOS:"
  /usr/bin/sw_vers
  echo
  echo "Uptime:"
  /usr/bin/uptime
  echo
  echo "Disk:"
  /bin/df -h /
  echo
  echo "Memory:"
  /usr/bin/vm_stat
  echo
  echo "Top CPU Processes:"
  { /bin/ps -arcwwwxo pid,pcpu,pmem,comm | /usr/bin/head -15; } || true
  echo
  echo "Top Memory Processes:"
  { /bin/ps -amcwwwxo pid,pmem,pcpu,comm | /usr/bin/head -15; } || true
} > "$REPORT_FILE"

echo "Saved system report: $REPORT_FILE"
