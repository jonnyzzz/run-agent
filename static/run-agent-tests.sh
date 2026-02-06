#!/bin/bash
# Integration tests for unified run-agent.sh
set -euo pipefail
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
RUNS_DIR="${RUNS_DIR:-$BASE_DIR/runs}"

run_test() {
  local agent="$1" prompt="$2" expect_re="$3"
  local tmp_prompt="$BASE_DIR/.tmp-run-agent-prompt.txt"
  printf "%s" "$prompt" > "$tmp_prompt"

  # Run agent and capture RUN_ID
  local out
  out=$("$BASE_DIR/run-agent.sh" "$agent" "$BASE_DIR" "$tmp_prompt")
  local run_id
  run_id=$(printf "%s\n" "$out" | rg -o "RUN_ID=run_[0-9]{8}-[0-9]{6}-[0-9]+" | awk -F= '{print $2}' | tail -n1)
  if [ -z "$run_id" ]; then
    echo "FAILED: could not parse RUN_ID from output" >&2
    exit 1
  fi

  local run_dir="$RUNS_DIR/$run_id"
  if [ ! -d "$run_dir" ]; then
    echo "FAILED: run dir not found: $run_dir" >&2
    exit 1
  fi

  # Validate files
  for f in prompt.md cwd.txt agent-stdout.txt agent-stderr.txt run-agent.sh; do
    if [ ! -f "$run_dir/$f" ]; then
      echo "FAILED: missing $f in $run_dir" >&2
      exit 1
    fi
  done
  if [ -f "$run_dir/pid.txt" ]; then
    echo "FAILED: pid.txt should be removed after completion ($run_id)" >&2
    exit 1
  fi
  if ! rg -q "EXIT_CODE=" "$run_dir/cwd.txt"; then
    echo "FAILED: EXIT_CODE missing from cwd.txt ($run_id)" >&2
    exit 1
  fi

  # Validate output contains expected regex
  if ! rg -q "$expect_re" "$run_dir/agent-stdout.txt" "$run_dir/agent-stderr.txt"; then
    echo "FAILED: expected pattern not found in output for $run_id" >&2
    exit 1
  fi

  echo "PASS: $agent ($run_id)"
}

run_test "codex" "Test: What is 7*7? Reply with just the number." "49"
run_test "claude" "Test: Reply with the word OK." "OK"

echo "All run-agent tests passed."
