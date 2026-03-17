#!/bin/bash
# Unified agent runner. Creates a new run_XXX folder, runs the agent, and blocks until completion.
# Usage: ./run-agent.sh [agent] [cwd] [prompt_file]
#
# Source: https://run-agent.jonnyzzz.com/run-agent.sh
# Docs:   https://run-agent.jonnyzzz.com/
#
# Copyright 2026 Eugene Petrenko
# Licensed under the Apache License, Version 2.0
# https://run-agent.jonnyzzz.com/LICENSE
set -euo pipefail

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
RUNS_DIR="${RUNS_DIR:-$BASE_DIR/runs}"
MESSAGE_BUS="${MESSAGE_BUS:-$BASE_DIR/MESSAGE-BUS.md}"
export RUNS_DIR
export MESSAGE_BUS

# All agents that have a case entry below (source of truth for invocation)
BUILTIN_AGENTS="codex claude gemini"

# RUN_AGENT_AGENTS overrides which agents are available (must be a subset of BUILTIN_AGENTS).
# Default: all built-in agents. Set to e.g. "claude,codex" to hide gemini from help/validation.
if [ -n "${RUN_AGENT_AGENTS:-}" ]; then
  # Parse comma-separated, validate each is a builtin
  KNOWN_AGENTS=""
  IFS=',' read -ra _req_agents <<< "$RUN_AGENT_AGENTS"
  for _ra in "${_req_agents[@]}"; do
    _ra="$(echo "$_ra" | tr -d '[:space:]')"
    [ -z "$_ra" ] && continue
    _is_builtin=false
    for _ba in $BUILTIN_AGENTS; do
      if [ "$_ra" = "$_ba" ]; then
        _is_builtin=true
        break
      fi
    done
    if [ "$_is_builtin" = false ]; then
      echo "RUN_AGENT_AGENTS: unknown agent '$_ra'. Built-in agents: ${BUILTIN_AGENTS// /,}" >&2
      exit 2
    fi
    KNOWN_AGENTS="${KNOWN_AGENTS:+$KNOWN_AGENTS }$_ra"
  done
  if [ -z "$KNOWN_AGENTS" ]; then
    echo "RUN_AGENT_AGENTS: no valid agents specified. Built-in agents: ${BUILTIN_AGENTS// /,}" >&2
    exit 2
  fi
else
  KNOWN_AGENTS="$BUILTIN_AGENTS"
fi

show_help() {
  cat <<HELP
run-agent.sh — Unified AI Agent runner

Usage: ./run-agent.sh <agent> <cwd> <prompt_file>

Arguments:
  agent        Agent to run: ${KNOWN_AGENTS// /,}
  cwd          Working directory for the agent (default: script directory)
  prompt_file  Path to the prompt file (default: ./prompt.md)

Environment variables:
  RUNS_DIR            Override the runs output directory (default: ./runs)
  MESSAGE_BUS         Override the message bus file (default: ./MESSAGE-BUS.md)
  RUN_AGENT_AGENTS    Comma-separated list of available agents (default: all built-in)
  RUN_AGENT_ENABLED   Comma-separated list of enabled agents (default: all available)

Exit codes:
  0  Agent completed successfully
  1  Prompt file not found
  2  Unknown agent type
  3  Agent not enabled (via RUN_AGENT_ENABLED)

Output:
  Each run creates a directory under RUNS_DIR with:
    prompt.md          Copy of the prompt
    agent-stdout.txt   Agent stdout
    agent-stderr.txt   Agent stderr
    cwd.txt            Run metadata (RUN_ID, CWD, AGENT, CMD, EXIT_CODE, ...)
    run-agent.sh       Copy of the runner script
    pid.txt            Agent PID (removed on completion)

Source: https://run-agent.jonnyzzz.com/run-agent.sh
Docs:   https://run-agent.jonnyzzz.com/
HELP
}

# Handle help flags
case "${1:-}" in
  -h|--help|help)
    show_help
    exit 0
    ;;
esac

AGENT="${1:-codex}"
CWD="${2:-$BASE_DIR}"
PROMPT_FILE="${3:-$BASE_DIR/prompt.md}"

# Validate agent name: must be alphanumeric/underscore and in KNOWN_AGENTS
if [[ ! "$AGENT" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
  echo "Unknown agent: $AGENT" >&2
  echo "Known agents: ${KNOWN_AGENTS// /,}" >&2
  exit 2
fi

_agent_known=false
for _ka in $KNOWN_AGENTS; do
  if [ "$_ka" = "$AGENT" ]; then
    _agent_known=true
    break
  fi
done
if [ "$_agent_known" = false ]; then
  echo "Unknown agent: $AGENT" >&2
  echo "Known agents: ${KNOWN_AGENTS// /,}" >&2
  exit 2
fi

# Normalize prompt path to absolute
PROMPT_FILE="$(cd "$(dirname "$PROMPT_FILE")" && pwd)/$(basename "$PROMPT_FILE")"
if [ ! -f "$PROMPT_FILE" ]; then
  echo "Prompt file not found: $PROMPT_FILE" >&2
  exit 1
fi

# Normalize CWD to absolute path
CWD="$(cd "$CWD" && pwd)"

# Check if the requested agent is enabled via RUN_AGENT_ENABLED
# Default: all agents enabled (empty or unset means all enabled)
if [ -n "${RUN_AGENT_ENABLED:-}" ]; then
  _agent_allowed=false
  IFS=',' read -ra _enabled_agents <<< "$RUN_AGENT_ENABLED"
  for _ea in "${_enabled_agents[@]}"; do
    _ea="$(echo "$_ea" | tr -d '[:space:]')"
    if [ "$_ea" = "$AGENT" ]; then
      _agent_allowed=true
      break
    fi
  done
  if [ "$_agent_allowed" = false ]; then
    echo "Agent '$AGENT' is not enabled. Enabled agents: $RUN_AGENT_ENABLED" >&2
    exit 3
  fi
fi

# Build agent command array — properly quoted, no eval needed.
# To add a new agent, add a case entry here and update KNOWN_AGENTS above.
AGENT_CMD=()
case "$AGENT" in
  codex)
    AGENT_CMD=(codex exec --dangerously-bypass-approvals-and-sandbox -C "$CWD" -)
    ;;
  claude)
    AGENT_CMD=(claude -p --input-format text --output-format text --tools default --permission-mode bypassPermissions)
    ;;
  gemini)
    AGENT_CMD=(gemini --screen-reader true --approval-mode yolo)
    ;;
  *)
    echo "Unknown agent: $AGENT" >&2
    echo "Known agents: ${KNOWN_AGENTS// /,}" >&2
    exit 2
    ;;
esac

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

CMDLINE="${AGENT_CMD[*]} < \"$RUN_DIR/prompt.md\""
(
  cd "$CWD"
  "${AGENT_CMD[@]}" <"$RUN_DIR/prompt.md" 1>"$STDOUT_FILE" 2>"$STDERR_FILE"
) &

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

EXIT_CODE=0
wait "$AGENT_PID" || EXIT_CODE=$?
rm -f "$PID_FILE"
echo "EXIT_CODE=$EXIT_CODE" >> "$CWD_FILE"
exit "$EXIT_CODE"
