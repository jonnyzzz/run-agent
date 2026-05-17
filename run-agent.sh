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
mkdir -p "$RUNS_DIR"
RUNS_DIR="$(cd "$RUNS_DIR" && pwd)"
MESSAGE_BUS="$RUNS_DIR/MESSAGE-BUS.md"
export RUNS_DIR
export MESSAGE_BUS

# All agents that have a case entry below (source of truth for invocation)
BUILTIN_AGENTS="codex claude gemini"

# RUN_AGENT_AGENTS overrides which agents are available (must be a subset of BUILTIN_AGENTS).
# Default: all built-in agents. Set to e.g. "claude,codex" to hide gemini from help/validation.
if [ -n "${RUN_AGENT_AGENTS:-}" ]; then
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
  agent        Agent to run: any,${KNOWN_AGENTS// /,}
               Use "any" to pick a random agent from the available list.
  cwd          Working directory for the agent (default: script directory)
  prompt_file  Path to the prompt file (default: ./prompt.md)

Configuration (env variables):
  RUNS_DIR            Runs output directory (default: ./runs)
  RUN_AGENT_AGENTS    Comma-separated list of available agents (default: all built-in)

Exported to agent process:
  RUNS_DIR            Absolute path to the runs directory
  MESSAGE_BUS         Absolute path to MESSAGE-BUS.md (inside RUNS_DIR)
  RUN_ID              Unique run identifier for this invocation
  PROMPT              Absolute path to the copied prompt file

Exit codes:
  0    Agent completed successfully
  1    Prompt file not found
  2    Unknown agent type
  129  Terminated by SIGHUP
  130  Terminated by SIGINT
  143  Terminated by SIGTERM

Output:
  Each run creates a directory under RUNS_DIR with:
    prompt.md          Copy of the prompt
    agent-stdout.txt   Agent stdout
    agent-stderr.txt   Agent stderr
    run-info.txt       Run metadata (RUN_ID, CWD, AGENT, CMD, EXIT_CODE, ...)
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

AGENT="${1:-any}"
CWD="${2:-$BASE_DIR}"
PROMPT_FILE="${3:-$BASE_DIR/prompt.md}"

# "any" picks a random agent from KNOWN_AGENTS
if [ "$AGENT" = "any" ]; then
  # shellcheck disable=SC2206
  _agents_arr=($KNOWN_AGENTS)
  AGENT="${_agents_arr[$((RANDOM % ${#_agents_arr[@]}))]}"
  echo "AGENT_SELECTED=$AGENT"
fi

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

# Sanitize environment: remove CLAUDECODE to avoid leaking nested runtime context
unset CLAUDECODE

# Build agent command array — properly quoted, no eval needed.
# To add a new agent, add a case entry here and update BUILTIN_AGENTS above.
AGENT_CMD=()
case "$AGENT" in
  codex)
    AGENT_CMD=(codex exec --dangerously-bypass-approvals-and-sandbox -C "$CWD" -)
    ;;
  claude)
    AGENT_CMD=(claude -p --input-format text --output-format text --tools default --permission-mode bypassPermissions)
    ;;
  gemini)
    AGENT_CMD=(gemini --screen-reader true --sandbox=false --approval-mode yolo --include-directories "$CWD")
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

# Compose a CMD= field that can be pasted into a shell verbatim.
# printf %q quotes each token so spaces / shell metacharacters in $CWD
# or $PROMPT do not corrupt the field when readers split on whitespace.
_quoted_cmd=""
for _arg in "${AGENT_CMD[@]}"; do
  _quoted_cmd+="$(printf '%q' "$_arg") "
done

# Export variables available to the agent process
PROMPT="$RUN_DIR/prompt.md"
export RUN_ID
export PROMPT

# Standard file names
STDOUT_FILE="$RUN_DIR/agent-stdout.txt"
STDERR_FILE="$RUN_DIR/agent-stderr.txt"
PID_FILE="$RUN_DIR/pid.txt"
RUN_INFO_FILE="$RUN_DIR/run-info.txt"

cp "$PROMPT_FILE" "$PROMPT"

CMDLINE="${_quoted_cmd}< $(printf '%q' "$PROMPT")"

# Signal handler. AGENT_PID may still be empty if the trap fires before
# the fork; the guards make that case a no-op.
AGENT_PID=""
on_signal() {
  local sig="$1" code="$2"
  if [ -n "$AGENT_PID" ]; then
    kill -TERM "$AGENT_PID" 2>/dev/null || true
    wait "$AGENT_PID" 2>/dev/null || true
  fi
  rm -f "$PID_FILE" 2>/dev/null || true
  { printf 'EXIT_CODE=%s\nSIGNAL=%s\n' "$code" "$sig" >> "$RUN_INFO_FILE"; } || true
  exit "$code"
}
trap 'on_signal INT  130' INT
trap 'on_signal TERM 143' TERM
trap 'on_signal HUP  129' HUP

(
  cd "$CWD"
  "${AGENT_CMD[@]}" <"$PROMPT" 1>"$STDOUT_FILE" 2>"$STDERR_FILE"
) &
AGENT_PID=$!

# run-info.txt lands before pid.txt so a watcher that uses pid.txt as
# the "agent is up" signal can rely on run-info.txt already being
# readable when it fires.
RUN_INFO_BLOCK="RUN_ID=$RUN_ID
RUN_DIR=$RUN_DIR
CWD=$CWD
AGENT=$AGENT
CMD=$CMDLINE
PROMPT=$PROMPT
STDOUT=$STDOUT_FILE
STDERR=$STDERR_FILE
PID=$AGENT_PID"
printf '%s\n' "$RUN_INFO_BLOCK"
{ printf '%s\n' "$RUN_INFO_BLOCK" > "$RUN_INFO_FILE"; } || true
echo "$AGENT_PID" > "$PID_FILE"

EXIT_CODE=0
wait "$AGENT_PID" || EXIT_CODE=$?
rm -f "$PID_FILE"

# Record EXIT_CODE on both surfaces, but never let a failed write here
# shadow the agent's exit code (e.g. disk full, run dir removed mid-run).
echo "EXIT_CODE=$EXIT_CODE"
{ echo "EXIT_CODE=$EXIT_CODE" >> "$RUN_INFO_FILE"; } || true
exit "$EXIT_CODE"
