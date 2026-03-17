#!/bin/bash
# test-run-agent.sh — Acceptance tests for run-agent.sh
#
# Tests the run-agent.sh script using mock agent stubs (no real AI CLIs needed).
# Can run standalone or inside CI.
#
# Usage:
#   RUN_AGENT_SH=/path/to/run-agent.sh bash test-run-agent.sh
#
# If RUN_AGENT_SH is not set, the script looks for run-agent.sh relative to
# this script at ../../run-agent.sh (works when placed inside the run-agent repo
# as tests/test-run-agent.sh).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# --- Locate run-agent.sh ---
if [ -z "${RUN_AGENT_SH:-}" ]; then
  # Try parent directory first (tests/ inside run-agent repo)
  if [ -f "$SCRIPT_DIR/../run-agent.sh" ]; then
    RUN_AGENT_SH="$(cd "$SCRIPT_DIR/.." && pwd)/run-agent.sh"
  # Then try grandparent (tests/run-agent/ inside marinade repo with a copy)
  elif [ -f "$SCRIPT_DIR/../../run-agent.sh" ]; then
    RUN_AGENT_SH="$(cd "$SCRIPT_DIR/../.." && pwd)/run-agent.sh"
  else
    RUN_AGENT_SH="$SCRIPT_DIR/../run-agent.sh"
  fi
fi

if [ ! -f "$RUN_AGENT_SH" ]; then
  echo "ERROR: run-agent.sh not found at $RUN_AGENT_SH" >&2
  echo "Set RUN_AGENT_SH=/path/to/run-agent.sh and retry." >&2
  exit 1
fi

RUN_AGENT_SH="$(cd "$(dirname "$RUN_AGENT_SH")" && pwd)/$(basename "$RUN_AGENT_SH")"
echo "Testing: $RUN_AGENT_SH"
echo ""

# --- Test scaffolding ---
PASS=0
FAIL=0
TEST_TMP=""

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

setup_tmp() {
  TEST_TMP="$(mktemp -d /tmp/run-agent-test-XXXXX)"
}

cleanup() {
  if [ -n "$TEST_TMP" ] && [ -d "$TEST_TMP" ] && [[ "$TEST_TMP" == /tmp/* ]]; then
    rm -rf "$TEST_TMP"
  fi
}
trap cleanup EXIT

# Create a temp dir with mock agent scripts on PATH
create_mock_agents() {
  local mock_bin="$TEST_TMP/mock-bin"
  mkdir -p "$mock_bin"

  # Mock claude: echoes "MOCK_CLAUDE_OK" to stdout
  cat > "$mock_bin/claude" <<'MOCK'
#!/bin/bash
echo "MOCK_CLAUDE_OK"
exit 0
MOCK
  chmod +x "$mock_bin/claude"

  # Mock codex: echoes "MOCK_CODEX_OK" to stdout
  cat > "$mock_bin/codex" <<'MOCK'
#!/bin/bash
echo "MOCK_CODEX_OK"
exit 0
MOCK
  chmod +x "$mock_bin/codex"

  # Mock gemini: echoes "MOCK_GEMINI_OK" to stdout
  cat > "$mock_bin/gemini" <<'MOCK'
#!/bin/bash
echo "MOCK_GEMINI_OK"
exit 0
MOCK
  chmod +x "$mock_bin/gemini"

  # Mock agent that exits with non-zero
  cat > "$mock_bin/claude-fail" <<'MOCK'
#!/bin/bash
echo "MOCK_CLAUDE_FAIL" >&2
exit 42
MOCK
  chmod +x "$mock_bin/claude-fail"

  # Mock agent that writes to both stdout and stderr
  cat > "$mock_bin/claude-verbose" <<'MOCK'
#!/bin/bash
echo "STDOUT_LINE"
echo "STDERR_LINE" >&2
exit 0
MOCK
  chmod +x "$mock_bin/claude-verbose"

  echo "$mock_bin"
}

# Create a temporary prompt file
create_prompt() {
  local content="${1:-Test prompt content}"
  local prompt_file="$TEST_TMP/test-prompt.md"
  printf "%s" "$content" > "$prompt_file"
  echo "$prompt_file"
}

# Prepare a working copy of run-agent.sh in a temp dir so RUNS_DIR is isolated
prepare_workspace() {
  local ws="$TEST_TMP/workspace"
  mkdir -p "$ws"
  cp "$RUN_AGENT_SH" "$ws/run-agent.sh"
  chmod +x "$ws/run-agent.sh"
  echo "$ws"
}

# ============================================================
# Tests
# ============================================================

echo "=== run-agent.sh Acceptance Tests ==="
echo ""

# --- Test 1: Script structure ---
echo "--- Test 1: Script structure ---"

if [ -x "$RUN_AGENT_SH" ]; then
  pass "run-agent.sh is executable"
else
  fail "run-agent.sh is NOT executable"
fi

if head -1 "$RUN_AGENT_SH" | grep -q "^#!/bin/bash"; then
  pass "run-agent.sh has bash shebang"
else
  fail "run-agent.sh missing bash shebang"
fi

if grep -q "set -euo pipefail" "$RUN_AGENT_SH"; then
  pass "run-agent.sh uses set -euo pipefail"
else
  fail "run-agent.sh missing set -euo pipefail"
fi

# --- Test 2: Missing prompt file ---
echo ""
echo "--- Test 2: Missing prompt file → exit 1 ---"
setup_tmp

ws="$(prepare_workspace)"
out=""
err=""
rc=0
out=$(RUNS_DIR="$TEST_TMP/runs2" "$ws/run-agent.sh" claude "$ws" "$TEST_TMP/nonexistent-prompt.md" 2>"$TEST_TMP/stderr2.txt") || rc=$?
err=$(cat "$TEST_TMP/stderr2.txt")

if [ "$rc" -eq 1 ]; then
  pass "exit code is 1 for missing prompt"
else
  fail "exit code is $rc, expected 1 for missing prompt"
fi

if echo "$err" | grep -qi "not found"; then
  pass "stderr mentions 'not found'"
else
  fail "stderr does not mention 'not found': $err"
fi

# --- Test 3: Unknown agent type ---
echo ""
echo "--- Test 3: Unknown agent type → exit 2 ---"

prompt_file="$(create_prompt "hello")"
rc=0
out=$(RUNS_DIR="$TEST_TMP/runs3" "$ws/run-agent.sh" unknown_agent "$ws" "$prompt_file" 2>"$TEST_TMP/stderr3.txt") || rc=$?
err=$(cat "$TEST_TMP/stderr3.txt")

if [ "$rc" -eq 2 ]; then
  pass "exit code is 2 for unknown agent"
else
  fail "exit code is $rc, expected 2 for unknown agent"
fi

if echo "$err" | grep -qi "unknown agent"; then
  pass "stderr mentions 'Unknown agent'"
else
  fail "stderr does not mention 'Unknown agent': $err"
fi

# --- Test 4: Successful claude run (mock) ---
echo ""
echo "--- Test 4: Successful claude run with mock agent ---"

mock_bin="$(create_mock_agents)"
prompt_file="$(create_prompt "Test prompt for claude")"
runs_dir="$TEST_TMP/runs4"

rc=0
out=$(PATH="$mock_bin:$PATH" RUNS_DIR="$runs_dir" "$ws/run-agent.sh" claude "$ws" "$prompt_file" 2>"$TEST_TMP/stderr4.txt") || rc=$?

if [ "$rc" -eq 0 ]; then
  pass "claude mock run exits 0"
else
  fail "claude mock run exits $rc, expected 0"
fi

# Parse RUN_ID from output
run_id=$(echo "$out" | grep "^RUN_ID=" | head -1 | cut -d= -f2)
if [ -n "$run_id" ]; then
  pass "RUN_ID parsed from output: $run_id"
else
  fail "could not parse RUN_ID from output"
fi

run_dir="$runs_dir/$run_id"
if [ -d "$run_dir" ]; then
  pass "run directory created: $run_dir"
else
  fail "run directory NOT created"
fi

# Check all expected files
for f in prompt.md cwd.txt agent-stdout.txt agent-stderr.txt run-agent.sh; do
  if [ -f "$run_dir/$f" ]; then
    pass "$f exists in run dir"
  else
    fail "$f MISSING from run dir"
  fi
done

# pid.txt should be removed after completion
if [ ! -f "$run_dir/pid.txt" ]; then
  pass "pid.txt removed after completion"
else
  fail "pid.txt still exists after completion"
fi

# Check prompt.md is a copy of the original
if diff -q "$prompt_file" "$run_dir/prompt.md" >/dev/null 2>&1; then
  pass "prompt.md is a copy of the original prompt"
else
  fail "prompt.md differs from original prompt"
fi

# Check agent-stdout.txt contains mock output
if grep -q "MOCK_CLAUDE_OK" "$run_dir/agent-stdout.txt"; then
  pass "agent-stdout.txt contains mock claude output"
else
  fail "agent-stdout.txt missing mock claude output"
fi

# Check cwd.txt contains expected metadata
for key in RUN_ID CWD AGENT CMD PROMPT STDOUT STDERR PID EXIT_CODE; do
  if grep -q "^${key}=" "$run_dir/cwd.txt"; then
    pass "cwd.txt contains $key"
  else
    fail "cwd.txt missing $key"
  fi
done

# Check AGENT value in cwd.txt
if grep -q "^AGENT=claude" "$run_dir/cwd.txt"; then
  pass "cwd.txt AGENT=claude"
else
  fail "cwd.txt AGENT is not claude"
fi

# Check EXIT_CODE=0
if grep -q "^EXIT_CODE=0" "$run_dir/cwd.txt"; then
  pass "cwd.txt EXIT_CODE=0"
else
  fail "cwd.txt EXIT_CODE is not 0"
fi

# --- Test 5: Successful codex run (mock) ---
echo ""
echo "--- Test 5: Successful codex run with mock agent ---"

prompt_file="$(create_prompt "Test prompt for codex")"
runs_dir="$TEST_TMP/runs5"

rc=0
out=$(PATH="$mock_bin:$PATH" RUNS_DIR="$runs_dir" "$ws/run-agent.sh" codex "$ws" "$prompt_file" 2>"$TEST_TMP/stderr5.txt") || rc=$?

if [ "$rc" -eq 0 ]; then
  pass "codex mock run exits 0"
else
  fail "codex mock run exits $rc, expected 0"
fi

run_id=$(echo "$out" | grep "^RUN_ID=" | head -1 | cut -d= -f2)
run_dir="$runs_dir/$run_id"

if grep -q "MOCK_CODEX_OK" "$run_dir/agent-stdout.txt"; then
  pass "agent-stdout.txt contains mock codex output"
else
  fail "agent-stdout.txt missing mock codex output"
fi

if grep -q "^AGENT=codex" "$run_dir/cwd.txt"; then
  pass "cwd.txt AGENT=codex"
else
  fail "cwd.txt AGENT is not codex"
fi

# --- Test 6: Successful gemini run (mock) ---
echo ""
echo "--- Test 6: Successful gemini run with mock agent ---"

prompt_file="$(create_prompt "Test prompt for gemini")"
runs_dir="$TEST_TMP/runs6"

rc=0
out=$(PATH="$mock_bin:$PATH" RUNS_DIR="$runs_dir" "$ws/run-agent.sh" gemini "$ws" "$prompt_file" 2>"$TEST_TMP/stderr6.txt") || rc=$?

if [ "$rc" -eq 0 ]; then
  pass "gemini mock run exits 0"
else
  fail "gemini mock run exits $rc, expected 0"
fi

run_id=$(echo "$out" | grep "^RUN_ID=" | head -1 | cut -d= -f2)
run_dir="$runs_dir/$run_id"

if grep -q "MOCK_GEMINI_OK" "$run_dir/agent-stdout.txt"; then
  pass "agent-stdout.txt contains mock gemini output"
else
  fail "agent-stdout.txt missing mock gemini output"
fi

if grep -q "^AGENT=gemini" "$run_dir/cwd.txt"; then
  pass "cwd.txt AGENT=gemini"
else
  fail "cwd.txt AGENT is not gemini"
fi

# --- Test 7: Exit code propagation ---
echo ""
echo "--- Test 7: Non-zero exit code propagation ---"

# Create a mock claude that exits 42
fail_bin="$TEST_TMP/fail-bin"
mkdir -p "$fail_bin"
cat > "$fail_bin/claude" <<'MOCK'
#!/bin/bash
echo "FAILING_AGENT" >&2
exit 42
MOCK
chmod +x "$fail_bin/claude"

prompt_file="$(create_prompt "Test failing agent")"
runs_dir="$TEST_TMP/runs7"

rc=0
out=$(PATH="$fail_bin:$PATH" RUNS_DIR="$runs_dir" "$ws/run-agent.sh" claude "$ws" "$prompt_file" 2>"$TEST_TMP/stderr7.txt") || rc=$?

if [ "$rc" -eq 42 ]; then
  pass "exit code 42 propagated from failing agent"
else
  fail "exit code is $rc, expected 42"
fi

run_id=$(echo "$out" | grep "^RUN_ID=" | head -1 | cut -d= -f2)
run_dir="$runs_dir/$run_id"

if [ ! -f "$run_dir/pid.txt" ]; then
  pass "pid.txt removed after failed run"
else
  fail "pid.txt still exists after failed run"
fi

if grep -q "^EXIT_CODE=42" "$run_dir/cwd.txt"; then
  pass "cwd.txt records EXIT_CODE=42"
else
  fail "cwd.txt does not record EXIT_CODE=42"
fi

# --- Test 8: RUNS_DIR env override ---
echo ""
echo "--- Test 8: RUNS_DIR env var override ---"

prompt_file="$(create_prompt "Test RUNS_DIR override")"
custom_runs="$TEST_TMP/custom-runs-dir"

rc=0
out=$(PATH="$mock_bin:$PATH" RUNS_DIR="$custom_runs" "$ws/run-agent.sh" claude "$ws" "$prompt_file" 2>/dev/null) || rc=$?

run_id=$(echo "$out" | grep "^RUN_ID=" | head -1 | cut -d= -f2)

if [ -d "$custom_runs/$run_id" ]; then
  pass "run directory created under custom RUNS_DIR"
else
  fail "run directory NOT created under custom RUNS_DIR"
fi

# --- Test 9: Stdout and stderr separation ---
echo ""
echo "--- Test 9: Stdout and stderr are captured separately ---"

verbose_bin="$TEST_TMP/verbose-bin"
mkdir -p "$verbose_bin"
cat > "$verbose_bin/claude" <<'MOCK'
#!/bin/bash
echo "STDOUT_CONTENT_HERE"
echo "STDERR_CONTENT_HERE" >&2
exit 0
MOCK
chmod +x "$verbose_bin/claude"

prompt_file="$(create_prompt "Test stdout/stderr separation")"
runs_dir="$TEST_TMP/runs9"

rc=0
out=$(PATH="$verbose_bin:$PATH" RUNS_DIR="$runs_dir" "$ws/run-agent.sh" claude "$ws" "$prompt_file" 2>/dev/null) || rc=$?
run_id=$(echo "$out" | grep "^RUN_ID=" | head -1 | cut -d= -f2)
run_dir="$runs_dir/$run_id"

if grep -q "STDOUT_CONTENT_HERE" "$run_dir/agent-stdout.txt"; then
  pass "stdout captured in agent-stdout.txt"
else
  fail "stdout NOT captured in agent-stdout.txt"
fi

if grep -q "STDERR_CONTENT_HERE" "$run_dir/agent-stderr.txt"; then
  pass "stderr captured in agent-stderr.txt"
else
  fail "stderr NOT captured in agent-stderr.txt"
fi

# Ensure no cross-contamination
if ! grep -q "STDERR_CONTENT_HERE" "$run_dir/agent-stdout.txt"; then
  pass "stderr does NOT leak into agent-stdout.txt"
else
  fail "stderr leaked into agent-stdout.txt"
fi

if ! grep -q "STDOUT_CONTENT_HERE" "$run_dir/agent-stderr.txt"; then
  pass "stdout does NOT leak into agent-stderr.txt"
else
  fail "stdout leaked into agent-stderr.txt"
fi

# --- Test 10: run-agent.sh self-copy ---
echo ""
echo "--- Test 10: run-agent.sh is self-copied to run directory ---"

prompt_file="$(create_prompt "Test self-copy")"
runs_dir="$TEST_TMP/runs10"

rc=0
out=$(PATH="$mock_bin:$PATH" RUNS_DIR="$runs_dir" "$ws/run-agent.sh" claude "$ws" "$prompt_file" 2>/dev/null) || rc=$?
run_id=$(echo "$out" | grep "^RUN_ID=" | head -1 | cut -d= -f2)
run_dir="$runs_dir/$run_id"

if diff -q "$ws/run-agent.sh" "$run_dir/run-agent.sh" >/dev/null 2>&1; then
  pass "run-agent.sh copied to run directory matches original"
else
  fail "run-agent.sh copy in run directory differs from original"
fi

# --- Test 11: RUN_ID format ---
echo ""
echo "--- Test 11: RUN_ID format validation ---"

prompt_file="$(create_prompt "Test RUN_ID format")"
runs_dir="$TEST_TMP/runs11"

rc=0
out=$(PATH="$mock_bin:$PATH" RUNS_DIR="$runs_dir" "$ws/run-agent.sh" claude "$ws" "$prompt_file" 2>/dev/null) || rc=$?
run_id=$(echo "$out" | grep "^RUN_ID=" | head -1 | cut -d= -f2)

if echo "$run_id" | grep -qE "^run_[0-9]{8}-[0-9]{6}-[0-9]+$"; then
  pass "RUN_ID matches expected format: run_YYYYMMDD-HHMMSS-PID"
else
  fail "RUN_ID format unexpected: $run_id"
fi

# --- Test 12: Output includes RUN_ID, RUN_DIR, PID ---
echo ""
echo "--- Test 12: Script output includes RUN_ID, RUN_DIR, PID ---"

prompt_file="$(create_prompt "Test output lines")"
runs_dir="$TEST_TMP/runs12"

rc=0
out=$(PATH="$mock_bin:$PATH" RUNS_DIR="$runs_dir" "$ws/run-agent.sh" claude "$ws" "$prompt_file" 2>/dev/null) || rc=$?

if echo "$out" | grep -q "^RUN_ID="; then
  pass "output contains RUN_ID="
else
  fail "output missing RUN_ID="
fi

if echo "$out" | grep -q "^RUN_DIR="; then
  pass "output contains RUN_DIR="
else
  fail "output missing RUN_DIR="
fi

if echo "$out" | grep -q "^PID="; then
  pass "output contains PID="
else
  fail "output missing PID="
fi

# --- Test 13: Relative prompt path normalization ---
echo ""
echo "--- Test 13: Relative prompt path is normalized to absolute ---"

# Create a prompt file with a known relative path
prompt_dir="$TEST_TMP/prompts"
mkdir -p "$prompt_dir"
echo "Relative path test" > "$prompt_dir/rel-prompt.md"
runs_dir="$TEST_TMP/runs13"

# Run from a different directory using a relative path
rc=0
out=$(cd "$prompt_dir" && PATH="$mock_bin:$PATH" RUNS_DIR="$runs_dir" "$ws/run-agent.sh" claude "$ws" "./rel-prompt.md" 2>/dev/null) || rc=$?

if [ "$rc" -eq 0 ]; then
  pass "relative prompt path accepted"
else
  fail "relative prompt path rejected with exit $rc"
fi

run_id=$(echo "$out" | grep "^RUN_ID=" | head -1 | cut -d= -f2)
run_dir="$runs_dir/$run_id"

# Verify the prompt was copied (proves path was resolved)
if [ -f "$run_dir/prompt.md" ] && grep -q "Relative path test" "$run_dir/prompt.md"; then
  pass "prompt.md copied correctly from relative path"
else
  fail "prompt.md not copied from relative path"
fi

# --- Test 14: CWD is passed to agent ---
echo ""
echo "--- Test 14: Working directory is passed to agent ---"

# Create a mock claude that records its CWD
cwd_bin="$TEST_TMP/cwd-bin"
mkdir -p "$cwd_bin"
cat > "$cwd_bin/claude" <<'MOCK'
#!/bin/bash
pwd
exit 0
MOCK
chmod +x "$cwd_bin/claude"

cwd_target="$TEST_TMP/agent-cwd-target"
mkdir -p "$cwd_target"
prompt_file="$(create_prompt "Test CWD")"
runs_dir="$TEST_TMP/runs14"

rc=0
out=$(PATH="$cwd_bin:$PATH" RUNS_DIR="$runs_dir" "$ws/run-agent.sh" claude "$cwd_target" "$prompt_file" 2>/dev/null) || rc=$?
run_id=$(echo "$out" | grep "^RUN_ID=" | head -1 | cut -d= -f2)
run_dir="$runs_dir/$run_id"

# The mock claude prints pwd, which should be the target CWD
cwd_target_real="$(cd "$cwd_target" && pwd)"
if grep -q "$cwd_target_real" "$run_dir/agent-stdout.txt"; then
  pass "agent runs in specified CWD"
else
  fail "agent CWD mismatch (expected $cwd_target_real)"
fi

# Check cwd.txt records the correct CWD
if grep -q "^CWD=$cwd_target_real" "$run_dir/cwd.txt" || grep -q "^CWD=$cwd_target" "$run_dir/cwd.txt"; then
  pass "cwd.txt records correct CWD"
else
  fail "cwd.txt does not record correct CWD"
fi

# --- Test 15: MESSAGE_BUS env var is exported ---
echo ""
echo "--- Test 15: MESSAGE_BUS env var is set ---"

# We verify by checking that the script sets/exports MESSAGE_BUS
if grep -q 'MESSAGE_BUS=' "$RUN_AGENT_SH" && grep -q 'export MESSAGE_BUS' "$RUN_AGENT_SH"; then
  pass "run-agent.sh sets and exports MESSAGE_BUS"
else
  fail "run-agent.sh does not set/export MESSAGE_BUS"
fi

# Also verify RUNS_DIR is exported
if grep -q 'export RUNS_DIR' "$RUN_AGENT_SH"; then
  pass "run-agent.sh exports RUNS_DIR"
else
  fail "run-agent.sh does not export RUNS_DIR"
fi

# --- Test 16: Multiple concurrent runs get unique IDs ---
echo ""
echo "--- Test 16: Concurrent runs get unique run directories ---"

prompt_file="$(create_prompt "Concurrent test")"
runs_dir="$TEST_TMP/runs16"

# Use a slow mock to ensure overlap
slow_bin="$TEST_TMP/slow-bin"
mkdir -p "$slow_bin"
cat > "$slow_bin/claude" <<'MOCK'
#!/bin/bash
sleep 0.1
echo "SLOW_DONE"
exit 0
MOCK
chmod +x "$slow_bin/claude"

# Launch two runs in parallel
out1_file="$TEST_TMP/out16_1.txt"
out2_file="$TEST_TMP/out16_2.txt"

PATH="$slow_bin:$PATH" RUNS_DIR="$runs_dir" "$ws/run-agent.sh" claude "$ws" "$prompt_file" > "$out1_file" 2>/dev/null &
pid1=$!
PATH="$slow_bin:$PATH" RUNS_DIR="$runs_dir" "$ws/run-agent.sh" claude "$ws" "$prompt_file" > "$out2_file" 2>/dev/null &
pid2=$!
wait "$pid1" "$pid2" 2>/dev/null || true

run_id1=$(grep "^RUN_ID=" "$out1_file" | head -1 | cut -d= -f2)
run_id2=$(grep "^RUN_ID=" "$out2_file" | head -1 | cut -d= -f2)

if [ -n "$run_id1" ] && [ -n "$run_id2" ] && [ "$run_id1" != "$run_id2" ]; then
  pass "concurrent runs have unique RUN_IDs"
else
  fail "concurrent runs have duplicate or missing RUN_IDs: '$run_id1' vs '$run_id2'"
fi

# --- Test 17: RUN_AGENT_ENABLED unset — all agents enabled (default) ---
echo ""
echo "--- Test 17: RUN_AGENT_ENABLED unset — all agents enabled ---"

prompt_file="$(create_prompt "Test default enabled")"
runs_dir="$TEST_TMP/runs17"

# Ensure RUN_AGENT_ENABLED is not set, run claude
rc=0
out=$(unset RUN_AGENT_ENABLED; PATH="$mock_bin:$PATH" RUNS_DIR="$runs_dir" "$ws/run-agent.sh" claude "$ws" "$prompt_file" 2>/dev/null) || rc=$?

if [ "$rc" -eq 0 ]; then
  pass "claude runs when RUN_AGENT_ENABLED is unset"
else
  fail "claude rejected (exit $rc) when RUN_AGENT_ENABLED is unset"
fi

# Also verify codex works with unset
rc=0
out=$(unset RUN_AGENT_ENABLED; PATH="$mock_bin:$PATH" RUNS_DIR="$runs_dir" "$ws/run-agent.sh" codex "$ws" "$prompt_file" 2>/dev/null) || rc=$?

if [ "$rc" -eq 0 ]; then
  pass "codex runs when RUN_AGENT_ENABLED is unset"
else
  fail "codex rejected (exit $rc) when RUN_AGENT_ENABLED is unset"
fi

# Also verify gemini works with unset
rc=0
out=$(unset RUN_AGENT_ENABLED; PATH="$mock_bin:$PATH" RUNS_DIR="$runs_dir" "$ws/run-agent.sh" gemini "$ws" "$prompt_file" 2>/dev/null) || rc=$?

if [ "$rc" -eq 0 ]; then
  pass "gemini runs when RUN_AGENT_ENABLED is unset"
else
  fail "gemini rejected (exit $rc) when RUN_AGENT_ENABLED is unset"
fi

# --- Test 18: RUN_AGENT_ENABLED empty — all agents enabled ---
echo ""
echo "--- Test 18: RUN_AGENT_ENABLED empty — all agents enabled ---"

prompt_file="$(create_prompt "Test empty enabled")"
runs_dir="$TEST_TMP/runs18"

rc=0
out=$(RUN_AGENT_ENABLED="" PATH="$mock_bin:$PATH" RUNS_DIR="$runs_dir" "$ws/run-agent.sh" claude "$ws" "$prompt_file" 2>/dev/null) || rc=$?

if [ "$rc" -eq 0 ]; then
  pass "claude runs when RUN_AGENT_ENABLED is empty"
else
  fail "claude rejected (exit $rc) when RUN_AGENT_ENABLED is empty"
fi

rc=0
out=$(RUN_AGENT_ENABLED="" PATH="$mock_bin:$PATH" RUNS_DIR="$runs_dir" "$ws/run-agent.sh" codex "$ws" "$prompt_file" 2>/dev/null) || rc=$?

if [ "$rc" -eq 0 ]; then
  pass "codex runs when RUN_AGENT_ENABLED is empty"
else
  fail "codex rejected (exit $rc) when RUN_AGENT_ENABLED is empty"
fi

# --- Test 19: Disabled agent is rejected with exit 3 ---
echo ""
echo "--- Test 19: Disabled agent is rejected with exit 3 ---"

prompt_file="$(create_prompt "Test disabled agent")"
runs_dir="$TEST_TMP/runs19"

# Enable only codex, try to run claude
rc=0
err=""
out=$(RUN_AGENT_ENABLED="codex" PATH="$mock_bin:$PATH" RUNS_DIR="$runs_dir" "$ws/run-agent.sh" claude "$ws" "$prompt_file" 2>"$TEST_TMP/stderr19.txt") || rc=$?
err=$(cat "$TEST_TMP/stderr19.txt")

if [ "$rc" -eq 3 ]; then
  pass "exit code is 3 for disabled agent"
else
  fail "exit code is $rc, expected 3 for disabled agent"
fi

if echo "$err" | grep -qi "not enabled"; then
  pass "stderr mentions 'not enabled'"
else
  fail "stderr does not mention 'not enabled': $err"
fi

if echo "$err" | grep -q "claude"; then
  pass "stderr mentions the disabled agent name"
else
  fail "stderr does not mention the disabled agent name"
fi

# --- Test 20: Enable only specific agents ---
echo ""
echo "--- Test 20: Enable only specific agents ---"

prompt_file="$(create_prompt "Test specific agents")"
runs_dir="$TEST_TMP/runs20"

# Enable only claude and gemini
rc=0
out=$(RUN_AGENT_ENABLED="claude,gemini" PATH="$mock_bin:$PATH" RUNS_DIR="$runs_dir" "$ws/run-agent.sh" claude "$ws" "$prompt_file" 2>/dev/null) || rc=$?

if [ "$rc" -eq 0 ]; then
  pass "claude runs when enabled in RUN_AGENT_ENABLED=claude,gemini"
else
  fail "claude rejected (exit $rc) when enabled"
fi

rc=0
out=$(RUN_AGENT_ENABLED="claude,gemini" PATH="$mock_bin:$PATH" RUNS_DIR="$runs_dir" "$ws/run-agent.sh" gemini "$ws" "$prompt_file" 2>/dev/null) || rc=$?

if [ "$rc" -eq 0 ]; then
  pass "gemini runs when enabled in RUN_AGENT_ENABLED=claude,gemini"
else
  fail "gemini rejected (exit $rc) when enabled"
fi

# codex should be rejected
rc=0
out=$(RUN_AGENT_ENABLED="claude,gemini" PATH="$mock_bin:$PATH" RUNS_DIR="$runs_dir" "$ws/run-agent.sh" codex "$ws" "$prompt_file" 2>"$TEST_TMP/stderr20.txt") || rc=$?

if [ "$rc" -eq 3 ]; then
  pass "codex rejected with exit 3 when not in RUN_AGENT_ENABLED=claude,gemini"
else
  fail "codex exit code is $rc, expected 3"
fi

# --- Test 21: Enable single agent ---
echo ""
echo "--- Test 21: Enable single agent ---"

prompt_file="$(create_prompt "Test single agent")"
runs_dir="$TEST_TMP/runs21"

rc=0
out=$(RUN_AGENT_ENABLED="codex" PATH="$mock_bin:$PATH" RUNS_DIR="$runs_dir" "$ws/run-agent.sh" codex "$ws" "$prompt_file" 2>/dev/null) || rc=$?

if [ "$rc" -eq 0 ]; then
  pass "codex runs when RUN_AGENT_ENABLED=codex"
else
  fail "codex rejected (exit $rc) when RUN_AGENT_ENABLED=codex"
fi

# claude and gemini should be rejected
rc=0
out=$(RUN_AGENT_ENABLED="codex" PATH="$mock_bin:$PATH" RUNS_DIR="$runs_dir" "$ws/run-agent.sh" claude "$ws" "$prompt_file" 2>/dev/null) || rc=$?

if [ "$rc" -eq 3 ]; then
  pass "claude rejected with exit 3 when RUN_AGENT_ENABLED=codex"
else
  fail "claude exit code is $rc, expected 3 when RUN_AGENT_ENABLED=codex"
fi

rc=0
out=$(RUN_AGENT_ENABLED="codex" PATH="$mock_bin:$PATH" RUNS_DIR="$runs_dir" "$ws/run-agent.sh" gemini "$ws" "$prompt_file" 2>/dev/null) || rc=$?

if [ "$rc" -eq 3 ]; then
  pass "gemini rejected with exit 3 when RUN_AGENT_ENABLED=codex"
else
  fail "gemini exit code is $rc, expected 3 when RUN_AGENT_ENABLED=codex"
fi

# --- Test 22: Disabled agent check happens before run dir artifacts ---
echo ""
echo "--- Test 22: Disabled agent exits before creating run directory ---"

prompt_file="$(create_prompt "Test no artifacts on disabled")"
runs_dir="$TEST_TMP/runs22"

rc=0
out=$(RUN_AGENT_ENABLED="codex" PATH="$mock_bin:$PATH" RUNS_DIR="$runs_dir" "$ws/run-agent.sh" claude "$ws" "$prompt_file" 2>/dev/null) || rc=$?

# Count directories under runs_dir — there should be none since the agent was rejected
if [ -d "$runs_dir" ]; then
  dir_count=$(find "$runs_dir" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d '[:space:]')
  if [ "$dir_count" -eq 0 ]; then
    pass "no run directory created when agent is disabled"
  else
    fail "run directory created even though agent was disabled (found $dir_count dirs)"
  fi
else
  pass "no run directory created when agent is disabled (runs dir does not exist)"
fi

# --- Test 23: Help flags ---
echo ""
echo "--- Test 23: Help flags (-h, --help, help) ---"

for flag in -h --help help; do
  rc=0
  out=$("$ws/run-agent.sh" "$flag" 2>/dev/null) || rc=$?

  if [ "$rc" -eq 0 ]; then
    pass "'$flag' exits 0"
  else
    fail "'$flag' exits $rc, expected 0"
  fi

  if echo "$out" | grep -q "Usage:"; then
    pass "'$flag' output contains Usage:"
  else
    fail "'$flag' output missing Usage:"
  fi

  if echo "$out" | grep -q "claude"; then
    pass "'$flag' output lists claude agent"
  else
    fail "'$flag' output missing claude agent"
  fi

  if echo "$out" | grep -q "RUNS_DIR"; then
    pass "'$flag' output mentions RUNS_DIR"
  else
    fail "'$flag' output missing RUNS_DIR"
  fi

  if echo "$out" | grep -q "RUN_AGENT_ENABLED"; then
    pass "'$flag' output mentions RUN_AGENT_ENABLED"
  else
    fail "'$flag' output missing RUN_AGENT_ENABLED"
  fi
done

# --- Test 24: Prompt content reaches agent stdin ---
echo ""
echo "--- Test 24: Prompt content reaches agent stdin ---"

stdin_bin="$TEST_TMP/stdin-bin"
mkdir -p "$stdin_bin"
cat > "$stdin_bin/claude" <<'MOCK'
#!/bin/bash
cat  # echo stdin to stdout
exit 0
MOCK
chmod +x "$stdin_bin/claude"

prompt_file="$(create_prompt "UNIQUE_PROMPT_CONTENT_12345")"
runs_dir="$TEST_TMP/runs24"

rc=0
out=$(PATH="$stdin_bin:$PATH" RUNS_DIR="$runs_dir" "$ws/run-agent.sh" claude "$ws" "$prompt_file" 2>/dev/null) || rc=$?
run_id=$(echo "$out" | grep "^RUN_ID=" | head -1 | cut -d= -f2)
run_dir="$runs_dir/$run_id"

if grep -q "UNIQUE_PROMPT_CONTENT_12345" "$run_dir/agent-stdout.txt"; then
  pass "prompt content delivered to agent stdin"
else
  fail "prompt content NOT delivered to agent stdin"
fi

# --- Test 25: Agent receives correct CLI arguments ---
echo ""
echo "--- Test 25: Agent receives correct CLI arguments ---"

args_bin="$TEST_TMP/args-bin"
mkdir -p "$args_bin"
cat > "$args_bin/claude" <<'MOCK'
#!/bin/bash
echo "ARGS:$*"
exit 0
MOCK
chmod +x "$args_bin/claude"

cat > "$args_bin/codex" <<'MOCK'
#!/bin/bash
echo "ARGS:$*"
exit 0
MOCK
chmod +x "$args_bin/codex"

prompt_file="$(create_prompt "arg test")"
runs_dir="$TEST_TMP/runs25"

# Test claude args
rc=0
out=$(PATH="$args_bin:$PATH" RUNS_DIR="$runs_dir" "$ws/run-agent.sh" claude "$ws" "$prompt_file" 2>/dev/null) || rc=$?
run_id=$(echo "$out" | grep "^RUN_ID=" | head -1 | cut -d= -f2)
run_dir="$runs_dir/$run_id"

if grep -q "\-\-permission-mode" "$run_dir/agent-stdout.txt"; then
  pass "claude receives --permission-mode flag"
else
  fail "claude missing --permission-mode flag"
fi

if grep -q "\-\-output-format" "$run_dir/agent-stdout.txt"; then
  pass "claude receives --output-format flag"
else
  fail "claude missing --output-format flag"
fi

# Test codex args — verify -C flag with correct CWD
rc=0
out=$(PATH="$args_bin:$PATH" RUNS_DIR="$runs_dir" "$ws/run-agent.sh" codex "$ws" "$prompt_file" 2>/dev/null) || rc=$?
run_id=$(echo "$out" | grep "^RUN_ID=" | head -1 | cut -d= -f2)
run_dir="$runs_dir/$run_id"

ws_real="$(cd "$ws" && pwd)"
if grep -q "\-C" "$run_dir/agent-stdout.txt"; then
  pass "codex receives -C flag"
else
  fail "codex missing -C flag"
fi

# --- Test 26: CWD with spaces ---
echo ""
echo "--- Test 26: CWD with spaces is handled correctly ---"

cwd_spaces="$TEST_TMP/path with spaces"
mkdir -p "$cwd_spaces"
prompt_file="$(create_prompt "spaces test")"
runs_dir="$TEST_TMP/runs26"

# Use a mock that prints pwd
cwd_check_bin="$TEST_TMP/cwd-check-bin"
mkdir -p "$cwd_check_bin"
cat > "$cwd_check_bin/claude" <<'MOCK'
#!/bin/bash
pwd
exit 0
MOCK
chmod +x "$cwd_check_bin/claude"

rc=0
out=$(PATH="$cwd_check_bin:$PATH" RUNS_DIR="$runs_dir" "$ws/run-agent.sh" claude "$cwd_spaces" "$prompt_file" 2>/dev/null) || rc=$?

if [ "$rc" -eq 0 ]; then
  pass "agent runs with CWD containing spaces"
else
  fail "agent fails (exit $rc) with CWD containing spaces"
fi

run_id=$(echo "$out" | grep "^RUN_ID=" | head -1 | cut -d= -f2)
run_dir="$runs_dir/$run_id"

if grep -q "path with spaces" "$run_dir/agent-stdout.txt"; then
  pass "agent CWD is correct with spaces"
else
  fail "agent CWD incorrect with spaces"
fi

# --- Test 27: Shell metacharacters in agent name are rejected ---
echo ""
echo "--- Test 27: Shell metacharacters in agent name are rejected ---"

prompt_file="$(create_prompt "injection test")"
runs_dir="$TEST_TMP/runs27"

for bad_name in '$(echo pwned)' 'foo;bar' 'agent name' '../etc'; do
  rc=0
  out=$(RUNS_DIR="$runs_dir" "$ws/run-agent.sh" "$bad_name" "$ws" "$prompt_file" 2>/dev/null) || rc=$?

  if [ "$rc" -eq 2 ] || [ "$rc" -eq 1 ]; then
    pass "agent name '$bad_name' rejected (exit $rc)"
  else
    fail "agent name '$bad_name' NOT rejected (exit $rc)"
  fi
done

# --- Test 28: Help does not create run directories ---
echo ""
echo "--- Test 28: Help does not create run directories ---"

runs_dir="$TEST_TMP/runs28"
mkdir -p "$runs_dir"

for flag in -h --help help; do
  out=$(RUNS_DIR="$runs_dir" "$ws/run-agent.sh" "$flag" 2>/dev/null) || true
  dir_count=$(find "$runs_dir" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d '[:space:]')
  if [ "$dir_count" -eq 0 ]; then
    pass "'$flag' creates no run directory"
  else
    fail "'$flag' created $dir_count run directories"
  fi
done

# --- Test 29: cwd.txt values are correct (not just present) ---
echo ""
echo "--- Test 29: cwd.txt values are correct ---"

prompt_file="$(create_prompt "value check")"
runs_dir="$TEST_TMP/runs29"

rc=0
out=$(PATH="$mock_bin:$PATH" RUNS_DIR="$runs_dir" "$ws/run-agent.sh" claude "$ws" "$prompt_file" 2>/dev/null) || rc=$?
run_id=$(echo "$out" | grep "^RUN_ID=" | head -1 | cut -d= -f2)
run_dir="$runs_dir/$run_id"
ws_real="$(cd "$ws" && pwd)"

# Check RUN_ID value matches what was printed
if grep -q "^RUN_ID=$run_id$" "$run_dir/cwd.txt"; then
  pass "cwd.txt RUN_ID value matches output"
else
  fail "cwd.txt RUN_ID value mismatch"
fi

# Check CWD is an absolute path
cwd_val=$(grep "^CWD=" "$run_dir/cwd.txt" | head -1 | cut -d= -f2)
if [[ "$cwd_val" == /* ]]; then
  pass "cwd.txt CWD is absolute path"
else
  fail "cwd.txt CWD is not absolute: $cwd_val"
fi

# Check CMD is non-empty
cmd_val=$(grep "^CMD=" "$run_dir/cwd.txt" | head -1 | cut -d= -f2-)
if [ -n "$cmd_val" ]; then
  pass "cwd.txt CMD is non-empty"
else
  fail "cwd.txt CMD is empty"
fi

# Check PID is numeric
pid_val=$(grep "^PID=" "$run_dir/cwd.txt" | head -1 | cut -d= -f2)
if [[ "$pid_val" =~ ^[0-9]+$ ]]; then
  pass "cwd.txt PID is numeric"
else
  fail "cwd.txt PID is not numeric: $pid_val"
fi

# --- Test 30: RUNS_DIR and MESSAGE_BUS are exported to agent ---
echo ""
echo "--- Test 30: RUNS_DIR and MESSAGE_BUS exported to agent ---"

env_bin="$TEST_TMP/env-bin"
mkdir -p "$env_bin"
cat > "$env_bin/claude" <<'MOCK'
#!/bin/bash
echo "RUNS_DIR=$RUNS_DIR"
echo "MESSAGE_BUS=$MESSAGE_BUS"
exit 0
MOCK
chmod +x "$env_bin/claude"

prompt_file="$(create_prompt "env test")"
runs_dir="$TEST_TMP/runs30"

rc=0
out=$(PATH="$env_bin:$PATH" RUNS_DIR="$runs_dir" MESSAGE_BUS="$TEST_TMP/bus.md" "$ws/run-agent.sh" claude "$ws" "$prompt_file" 2>/dev/null) || rc=$?
run_id=$(echo "$out" | grep "^RUN_ID=" | head -1 | cut -d= -f2)
run_dir="$runs_dir/$run_id"

if grep -q "RUNS_DIR=$runs_dir" "$run_dir/agent-stdout.txt"; then
  pass "RUNS_DIR exported to agent process"
else
  fail "RUNS_DIR NOT exported to agent process"
fi

if grep -q "MESSAGE_BUS=$TEST_TMP/bus.md" "$run_dir/agent-stdout.txt"; then
  pass "MESSAGE_BUS exported to agent process"
else
  fail "MESSAGE_BUS NOT exported to agent process"
fi

# --- Test 31: RUN_AGENT_ENABLED edge cases ---
echo ""
echo "--- Test 31: RUN_AGENT_ENABLED edge cases ---"

prompt_file="$(create_prompt "edge cases")"
runs_dir="$TEST_TMP/runs31"

# Trailing comma: "claude," should still enable claude
rc=0
out=$(RUN_AGENT_ENABLED="claude," PATH="$mock_bin:$PATH" RUNS_DIR="$runs_dir" "$ws/run-agent.sh" claude "$ws" "$prompt_file" 2>/dev/null) || rc=$?
if [ "$rc" -eq 0 ]; then
  pass "trailing comma: claude still enabled"
else
  fail "trailing comma: claude rejected (exit $rc)"
fi

# Whitespace around agent names: " claude " should work
rc=0
out=$(RUN_AGENT_ENABLED=" claude , codex " PATH="$mock_bin:$PATH" RUNS_DIR="$runs_dir" "$ws/run-agent.sh" claude "$ws" "$prompt_file" 2>/dev/null) || rc=$?
if [ "$rc" -eq 0 ]; then
  pass "whitespace in RUN_AGENT_ENABLED: claude enabled"
else
  fail "whitespace in RUN_AGENT_ENABLED: claude rejected (exit $rc)"
fi

# Substring non-match: "claude2" should NOT enable "claude"
rc=0
out=$(RUN_AGENT_ENABLED="claude2" PATH="$mock_bin:$PATH" RUNS_DIR="$runs_dir" "$ws/run-agent.sh" claude "$ws" "$prompt_file" 2>/dev/null) || rc=$?
if [ "$rc" -eq 3 ]; then
  pass "substring non-match: claude2 does not enable claude"
else
  fail "substring non-match: claude unexpectedly allowed (exit $rc)"
fi

# --- Test 32: CWD is normalized to absolute path ---
echo ""
echo "--- Test 32: CWD is normalized to absolute path in cwd.txt ---"

# Create a relative-path accessible directory
rel_dir="$TEST_TMP/rel-cwd-target"
mkdir -p "$rel_dir"
prompt_file="$(create_prompt "relative cwd")"
runs_dir="$TEST_TMP/runs32"

rc=0
out=$(cd "$TEST_TMP" && PATH="$mock_bin:$PATH" RUNS_DIR="$runs_dir" "$ws/run-agent.sh" claude "./rel-cwd-target" "$prompt_file" 2>/dev/null) || rc=$?

if [ "$rc" -eq 0 ]; then
  pass "relative CWD accepted"
else
  fail "relative CWD rejected (exit $rc)"
fi

run_id=$(echo "$out" | grep "^RUN_ID=" | head -1 | cut -d= -f2)
run_dir="$runs_dir/$run_id"

cwd_val=$(grep "^CWD=" "$run_dir/cwd.txt" | head -1 | cut -d= -f2)
if [[ "$cwd_val" == /* ]]; then
  pass "relative CWD normalized to absolute in cwd.txt"
else
  fail "CWD not normalized: $cwd_val"
fi

# ============================================================
# Summary
# ============================================================

echo ""
echo "=== Test Results ==="
echo "  PASSED: $PASS"
echo "  FAILED: $FAIL"
echo ""

if [ "$FAIL" -gt 0 ]; then
  echo "RESULT: FAIL ($FAIL test(s) failed)"
  exit 1
else
  echo "RESULT: PASS (all $PASS tests passed)"
  exit 0
fi
