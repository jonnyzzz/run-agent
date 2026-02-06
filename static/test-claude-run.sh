#!/bin/bash
# Quick sanity check for claude via unified run-agent.sh
set -euo pipefail
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
RUNS_DIR="${RUNS_DIR:-$BASE_DIR/runs}"

TMP_PROMPT="$BASE_DIR/.tmp-claude-prompt.txt"
cat > "$TMP_PROMPT" <<'PROMPT'
Say "CLAUDE OK". Then run shell commands `ls ~` and `ls -ld ~`. Log a FACT to MESSAGE-BUS.md with the outputs.
PROMPT

OUT=$("$BASE_DIR/run-agent.sh" claude "$BASE_DIR" "$TMP_PROMPT")
RUN_ID=$(printf "%s\n" "$OUT" | rg -o "RUN_ID=run_[0-9]{8}-[0-9]{6}-[0-9]+" | awk -F= '{print $2}' | tail -n1)
if [ -z "$RUN_ID" ]; then
  echo "Failed to parse RUN_ID from run-agent output" >&2
  exit 1
fi

RUN_DIR="$RUNS_DIR/$RUN_ID"
LOG_OUT="$RUN_DIR/agent-stdout.txt"
LOG_ERR="$RUN_DIR/agent-stderr.txt"

if ! rg -q "CLAUDE OK|ls ~|Logged a FACT|Done" "$LOG_OUT" "$LOG_ERR"; then
  echo "Claude output missing expected markers. Check $LOG_OUT / $LOG_ERR" >&2
  exit 1
fi

echo "Claude run succeeded. Run: $RUN_ID"
