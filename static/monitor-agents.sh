#!/bin/bash
# Monitor agent PIDs (from runs/*/*.pid) every 10 minutes and log to runs/agent-watch.log
set -euo pipefail
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
RUNS_DIR="${RUNS_DIR:-$BASE_DIR/runs}"
LOG="$RUNS_DIR/agent-watch.log"

while true; do
  ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  echo "[$ts] status check" | tee -a "$LOG"
  found=0
  while IFS= read -r -d '' run_dir; do
    found=1
    pid_file="$run_dir/pid.txt"
    if [ -f "$pid_file" ]; then
      pid=$(cat "$pid_file" || true)
      if [ -z "$pid" ]; then
        echo "  $run_dir: PID file empty" | tee -a "$LOG"
        continue
      fi
      if ps -p "$pid" >/dev/null 2>&1; then
        echo "  $run_dir: PID $pid running" | tee -a "$LOG"
      else
        echo "  $run_dir: PID $pid finished" | tee -a "$LOG"
      fi
      continue
    fi
    if rg -q "EXIT_CODE=" "$run_dir/cwd.txt" 2>/dev/null; then
      echo "  $run_dir: finished (exit recorded)" | tee -a "$LOG"
    else
      echo "  $run_dir: unknown (no pid/exit)" | tee -a "$LOG"
    fi
  done < <(find "$RUNS_DIR" -maxdepth 1 -type d -name "run_*" -print0 2>/dev/null)

  if [ $found -eq 0 ]; then
    echo "  no runs found" | tee -a "$LOG"
  fi

  sleep 600
 done
