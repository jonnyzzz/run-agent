#!/bin/bash
# Root agent 5-minute status loop: append agent status to MESSAGE-BUS.md every 300 seconds.
set -euo pipefail

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
RUNS_DIR="${RUNS_DIR:-$BASE_DIR/runs}"
BUS="${MESSAGE_BUS:-$BASE_DIR/MESSAGE-BUS.md}"
LOG="$RUNS_DIR/status-loop-5m.log"

while true; do
  ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  msg_id="MSG-$(date -u +%Y%m%d-%H%M%S)-orchestrator-status-loop-5m"

  running=()
  finished=()
  unknown=()
  while IFS= read -r -d '' run_dir; do
    run_name=$(basename "$run_dir")
    pid_file="$run_dir/pid.txt"
    if [ -f "$pid_file" ]; then
      pid=$(cat "$pid_file" 2>/dev/null || true)
      if [ -n "$pid" ] && ps -p "$pid" >/dev/null 2>&1; then
        running+=("$run_name:$pid")
      else
        finished+=("$run_name:$pid")
      fi
      continue
    fi
    if rg -q "EXIT_CODE=" "$run_dir/cwd.txt" 2>/dev/null; then
      finished+=("$run_name:exit")
    else
      unknown+=("$run_name:unknown")
    fi
  done < <(find "$RUNS_DIR" -maxdepth 1 -type d -name "run_*" -print0 2>/dev/null)

  run_count=${#running[@]}
  fin_count=${#finished[@]}
  unk_count=${#unknown[@]}
  running_list="none"
  if [ "$run_count" -gt 0 ]; then
    running_list=$(printf "%s " "${running[@]}" | sed 's/ $//')
  fi

  {
    echo "---"
    echo "messageId: $msg_id"
    echo "type: PROGRESS"
    echo "agent: orchestrator-root-0"
    echo "timestamp: $ts"
    echo "runId: N/A"
    echo "taskId: TASK-STATUS-LOOP-5M"
    echo "---"
    echo "Agent status (5m): running=$run_count finished=$fin_count unknown=$unk_count running_list=[$running_list]"
  } | tee -a "$BUS" >>"$LOG"

  sleep 300
done
