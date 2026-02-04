#!/bin/bash
# Unified agent runner. Creates a new run_XXX folder, runs the agent, and blocks until completion.
# Usage: ./run-agent.sh [agent] [cwd] [prompt_file]
set -euo pipefail

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
RUNS_DIR="${RUNS_DIR:-$BASE_DIR/runs}"
MESSAGE_BUS="${MESSAGE_BUS:-$BASE_DIR/MESSAGE-BUS.md}"
export RUNS_DIR
export MESSAGE_BUS

AGENT="${1:-codex}"
CWD="${2:-$BASE_DIR}"
PROMPT_FILE="${3:-$BASE_DIR/prompt.md}"

# Normalize prompt path to absolute
PROMPT_FILE="$(cd "$(dirname "$PROMPT_FILE")" && pwd)/$(basename "$PROMPT_FILE")"
if [ ! -f "$PROMPT_FILE" ]; then
  echo "Prompt file not found: $PROMPT_FILE" >&2
  exit 1
fi

RUN_ID="run_$(date -u +%Y%m%d-%H%M%S)-$$"
RUN_DIR="$RUNS_DIR/$RUN_ID"
mkdir -p "$RUN_DIR"
cp "$BASE_DIR/run-agent.sh" "$RUN_DIR/run-agent.sh"

echo "RUN_ID=$RUN_ID"
echo "RUN_DIR=$RUN_DIR"

# Standard file names
STDOUT_FILE="$RUN_DIR/agent-stdout.txt"
STDERR_FILE="$RUN_DIR/agent-stderr.txt"
PID_FILE="$RUN_DIR/pid.txt"
CWD_FILE="$RUN_DIR/cwd.txt"

cp "$PROMPT_FILE" "$RUN_DIR/prompt.md"

CMDLINE=""
case "$AGENT" in
  codex)
    CMDLINE="codex exec --dangerously-bypass-approvals-and-sandbox -C \"$CWD\" - < \"$RUN_DIR/prompt.md\""
    (
      cd "$CWD"
      codex exec --dangerously-bypass-approvals-and-sandbox -C "$CWD" - <"$RUN_DIR/prompt.md" 1>"$STDOUT_FILE" 2>"$STDERR_FILE"
    ) &
    ;;
  claude)
    CMDLINE="claude -p --input-format text --output-format text --tools default --permission-mode bypassPermissions < \"$RUN_DIR/prompt.md\""
    (
      cd "$CWD"
      claude -p --input-format text --output-format text --tools default --permission-mode bypassPermissions <"$RUN_DIR/prompt.md" 1>"$STDOUT_FILE" 2>"$STDERR_FILE"
    ) &
    ;;
  gemini)
    CMDLINE="gemini --screen-reader true --yolo --approval-mode yolo <\"$RUN_DIR/prompt.md\""
    (
      cd "$CWD"
      gemini --screen-reader true --yolo --approval-mode yolo <"$RUN_DIR/prompt.md" 1>"$STDOUT_FILE" 2>"$STDERR_FILE"
    ) &
    ;;
  *)
    echo "Unknown agent: $AGENT" >&2
    exit 2
    ;;
esac

AGENT_PID=$!
echo "$AGENT_PID" > "$PID_FILE"
echo "PID=$AGENT_PID"

cat > "$CWD_FILE" <<EOF
RUN_ID=$RUN_ID
CWD=$CWD
AGENT=$AGENT
CMD=$CMDLINE
PROMPT=$RUN_DIR/prompt.md
STDOUT=$STDOUT_FILE
STDERR=$STDERR_FILE
PID=$AGENT_PID
EOF

wait "$AGENT_PID"
EXIT_CODE=$?
rm -f "$PID_FILE"
echo "EXIT_CODE=$EXIT_CODE" >> "$CWD_FILE"
exit "$EXIT_CODE"
