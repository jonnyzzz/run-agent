# `run-agent.sh` — Behavioural Specification

A re-implementer MUST satisfy every requirement below. This document
describes externally observable behaviour only; nothing here prescribes
how the script must be structured internally.

---

## 1. Purpose

The script is a uniform launcher for command-line AI coding agents
(Claude, Codex, Gemini, Junie). Given an agent name, a working
directory and a prompt file, it MUST create an isolated per-run
directory, stage the user prompt with a handoff hint, compose a system
prompt, launch the chosen agent against that prompt in the target
working directory, supervise the agent process, capture its stdout and
stderr, and advertise the resulting handoff files on its own stdout so
a caller can grep them out. It also doubles as its own progress monitor
when invoked in `monitor` mode.

---

## 2. Invocation

The primary signature MUST be:

```
run-agent.sh <agent> <cwd> <prompt_file>
```

A secondary internal mode MUST be:

```
run-agent.sh monitor <directory>
```

Positional arguments in primary mode:

- `<agent>` — the agent selector (see §3).
- `<cwd>` — an existing directory the agent will be launched in.
- `<prompt_file>` — an existing regular file holding the user prompt.

Exit codes:

| Code  | Meaning                                                  |
| ----- | -------------------------------------------------------- |
| `0`   | Agent exited with `0`.                                   |
| `1`   | `<cwd>` does not exist, or `<prompt_file>` does not exist. |
| `2`   | Unknown agent name.                                      |
| `64`  | Fewer than three positional arguments supplied.          |
| `127` | Selected agent's CLI binary is not on `PATH`.             |
| `129` | Process terminated by `SIGHUP`.                          |
| `130` | Process terminated by `SIGINT`.                          |
| `143` | Process terminated by `SIGTERM`.                          |
| *N*   | For any other exit, the script MUST propagate the agent's exit code verbatim. |

Help mode: the script does NOT implement a dedicated `--help` flag.
Invoking with fewer than three arguments MUST print the one-line usage
banner above to stderr and exit `64`.

Verbose-trace mode: when the environment variable
`RUN_AGENT_VERBOSE_BASH` is set to one of `1`, `true`, `TRUE`, `yes`,
`YES`, `on`, `ON`, the script MUST enable shell tracing with a
`PS4` prefix of `+ run-agent.sh:<lineno>: `.

---

## 3. Supported agents

| Name     | Underlying CLI | Notes                                              |
| -------- | -------------- | -------------------------------------------------- |
| `claude` | `claude`       | Native `--append-system-prompt` flag.              |
| `codex`  | `codex`        | Native `model_instructions_file` config flag.      |
| `gemini` | `gemini`       | No system-prompt flag; uses prompt prepend (§5/§6).|
| `junie`  | `junie`        | No system-prompt flag; uses prompt prepend (§5/§6).|
| `any`    | (selector)     | See below.                                         |

When `<agent>` is `any`, the script MUST pick one entry from the
candidate pool `{claude, codex}` uniformly at random and re-invoke
itself with the chosen agent name and the remaining arguments
unchanged. The re-invocation MUST replace the current process (so the
caller sees a single PID).

When `<agent>` is anything else not in the table above, the script
MUST exit `2` with `run-agent.sh: unknown agent: <agent>` on stderr.

Before launching the agent, the script MUST verify that the chosen
agent's CLI binary is resolvable on `PATH`. If it is not, the script
MUST:

1. Print a human-readable error to stderr noting the missing binary.
2. Append a single grep-stable line of the form
   `AGENT_CLI_MISSING agent=<agent> cli=<binary>` to the run's
   `agent-stderr.txt`.
3. Exit `127`.

---

## 4. Inputs

### 4.1 Positional arguments

See §2.

### 4.2 Environment variables read

| Name                                 | Meaning                                                                                                          | Default                            | Exported to child? |
| ------------------------------------ | ---------------------------------------------------------------------------------------------------------------- | ---------------------------------- | ------------------ |
| `RUNS_DIR`                           | Parent directory under which the per-run folder is created. Resolved to an absolute path.                        | `<script-dir>/../runs`             | No (used in-process). |
| `RUN_AGENT_VERBOSE_BASH`             | Enable `set -x` tracing of the script itself.                                                                    | unset                              | No.                |
| `RUN_AGENT_SYSTEM_PROMPT_FILE`       | Path to a file appended to the composed system prompt at every nesting level.                                    | unset                              | No.                |
| `RUN_AGENT_SYSTEM_PROMPT_FILE_<N>`   | Path to a file appended to the composed system prompt only when the current nesting level equals `<N>`.          | unset                              | No.                |
| `RUN_AGENT_NESTING_LEVEL`            | Current nesting level (integer, root = `0`).                                                                     | `0`                                | Yes, set to `N+1`. |
| `RUN_ID`                             | Read at startup as the *parent* run id; then unset locally and replaced by the new run's id.                     | unset                              | Yes, re-set.       |
| `RUN_DIR`                            | Read at startup as the *parent* run directory; then unset locally and replaced by the new run's directory.       | unset                              | Yes, re-set.       |
| `PARENT_RUN_ID`                      | Carries the inherited `RUN_ID` (see §9).                                                                         | derived                            | Yes.               |
| `PARENT_RUN_DIR`                     | Carries the inherited `RUN_DIR` (see §9).                                                                        | derived                            | Yes.               |
| `ENSURE_HANDOFF_DIR`                 | Opaque flag re-exported into the generated `cmd.sh` only when present.                                           | unset                              | Through `cmd.sh`.  |
| `CLAUDE_MODEL`                       | Model id passed to the Claude CLI.                                                                               | `claude-opus-4-7`                  | Through agent CLI. |
| `CLAUDE_EFFORT`                      | Reasoning-effort flag passed to the Claude CLI.                                                                  | `xhigh`                            | Through agent CLI. |
| `CODEX_MODEL`                        | Model id passed to the Codex CLI.                                                                                | `gpt-5.5`                          | Through agent CLI. |
| `CODEX_EFFORT`                       | Reasoning-effort flag passed to the Codex CLI.                                                                   | `xhigh`                            | Through agent CLI. |
| `GEMINI_MODEL`                       | Model id passed to the Gemini CLI.                                                                               | `gemini-3.1-pro-preview`           | Through agent CLI. |
| `CLAUDECODE`                         | Parent Claude-session marker; MUST be unset before launching the child to avoid contamination.                   | n/a                                | No (explicitly unset). |

The script MUST NOT consume any other environment variables for its
own dispatch logic. Unrelated environment is inherited by the agent
verbatim.

### 4.3 Files read

- `<prompt_file>` — the caller's user prompt, copied verbatim into the
  staged prompt.
- `${RUN_AGENT_SYSTEM_PROMPT_FILE}` — when set and non-empty.
- `${RUN_AGENT_SYSTEM_PROMPT_FILE_<NESTING_LEVEL>}` — when set and
  non-empty.

---

## 5. Outputs

### 5.1 Per-run directory layout

A run directory MUST be created as `${RUNS_DIR}/run_<UTC-stamp>-<pid>`,
where `<UTC-stamp>` is `YYYYmmdd-HHMMSS` and `<pid>` is the script's
own PID. The directory MUST contain, after a normal finish:

- `prompt.md` — the staged prompt (user prompt + handoff hint block).
- `prompt-with-sysp.md` — the user prompt prepended with the composed
  system prompt; created only for the `gemini` / `junie` paths and only
  when env-driven system-prompt content actually landed.
- `system-prompt.md` — the composed system prompt (see §6).
- `cmd.sh` — an executable, standalone replay script that launches the
  agent with the same command line and the same dispatch-relevant
  environment.
- `agent-stdout.txt` — the agent's captured stdout.
- `agent-stderr.txt` — the agent's captured stderr.
- `pid.txt` — the agent's PID while it runs; MUST be removed after the
  agent exits or is killed.
- `run-info.txt` — the run-metadata file (see §5.2).
- `STATUS.md` / `RESULT.md` / `IMPROVEMENTS.md` — produced by the
  agent, not by the script (see §8). Their absence after the run is
  not an error from the script's perspective.

### 5.2 Run-metadata fields (`run-info.txt`)

The script MUST write `run-info.txt` as a flat `KEY=value` listing, one
field per line, in this order:

| Field                  | Source                                                          |
| ---------------------- | --------------------------------------------------------------- |
| `RUN_ID`               | The new run id.                                                 |
| `RUN_DIR`              | Absolute path to the run directory.                             |
| `CWD`                  | Absolute, canonicalised target working directory.               |
| `AGENT`                | The agent name actually selected.                               |
| `PID`                  | The agent's PID.                                                |
| `STDOUT`               | Absolute path to `agent-stdout.txt`.                            |
| `STDERR`               | Absolute path to `agent-stderr.txt`.                            |
| `CMD_SCRIPT`           | Absolute path to `cmd.sh`.                                      |
| `SOURCE_PROMPT`        | Absolute path to the original prompt file passed in.            |
| `HANDOFF_STATUS`       | Absolute path to `STATUS.md`.                                   |
| `HANDOFF_RESULT`       | Absolute path to `RESULT.md`.                                   |
| `HANDOFF_IMPROVEMENTS` | Absolute path to `IMPROVEMENTS.md`.                             |
| `PARENT_RUN_ID`        | Inherited parent run id; emitted only when non-empty.           |
| `PARENT_RUN_DIR`       | Inherited parent run dir; emitted only when non-empty.          |
| `STARTED`              | UTC ISO-8601 timestamp (`YYYY-mm-ddTHH:MM:SSZ`).                |
| `FINISHED`             | UTC ISO-8601 timestamp, appended after the agent exits.         |
| `EXIT_CODE`            | The agent's exit code, appended after the agent exits.          |
| `SIGNAL`               | Signal name, appended only when the script was killed by a signal. |

### 5.3 Stdout contract

The script MUST print, in order:

1. A literal line `--- run-agent.sh start ---`.
2. The full contents of `run-info.txt` as it stands before the agent runs.
3. After the agent exits, a literal line `--- run-agent.sh finish ---`.
4. The full updated contents of `run-info.txt` (now including `FINISHED`
   and `EXIT_CODE`).
5. A literal line `--- handoff files (read these for the result) ---`
   followed by three lines of the form `STATUS:       <path>`,
   `RESULT:       <path>`, `IMPROVEMENTS: <path>`.
6. When the agent exited non-zero, an additional literal line
   `--- agent stderr (exit=<code>) ---` followed by the verbatim
   contents of `agent-stderr.txt`.

The handoff block format MUST be stable so callers can grep
`HANDOFF_STATUS=`, `HANDOFF_RESULT=`, `HANDOFF_IMPROVEMENTS=` (from
`run-info.txt` echoed on stdout) and the labelled `STATUS:` / `RESULT:` /
`IMPROVEMENTS:` lines (from the trailer block) interchangeably.

### 5.4 Stderr contract

The script MAY only write to stderr for:

- Usage banner (when too few args).
- `cwd not found: <path>` / `prompt file not found: <path>`.
- `unknown agent: <agent>`.
- `<binary> binary not found in PATH; pool composition includes an uninstalled CLI`.

The `monitor` mode (§7) MUST redirect its own progress lines to stderr.
The agent's own stderr MUST NOT be merged into the script's stderr; it
goes to `agent-stderr.txt` instead.

---

## 6. Run lifecycle

The script MUST execute, in order:

1. **Argument validation.** Reject `<3` positional args (exit `64`).
   Canonicalise `<cwd>` to an absolute path; reject if missing
   (exit `1`). Canonicalise `<prompt_file>` to an absolute path and
   verify it is a regular file; reject otherwise (exit `1`).
2. **Agent selection.** If the agent is `any`, randomly pick from
   `{claude, codex}` and `exec` self with the resolved name. Otherwise
   keep the supplied name.
3. **Inherit nesting.** Capture the inbound `RUN_ID` / `RUN_DIR` into
   `PARENT_RUN_ID` / `PARENT_RUN_DIR`, then locally clear `RUN_ID` /
   `RUN_DIR` before assigning new values.
4. **Create run dir.** Compute `RUN_ID = run_<UTC-stamp>-<PID>` and
   `RUN_DIR = $RUNS_DIR/$RUN_ID`. Create the directory. Export both.
5. **Stage prompt.** Concatenate the user prompt with a per-run
   handoff hint block (markdown, separated by `---`) that instructs
   the agent to write `STATUS.md`, `RESULT.md`, and `IMPROVEMENTS.md`
   into the absolute `RUN_DIR`. Write the result to `prompt.md`.
6. **Compose system prompt.** Create `system-prompt.md` (empty). If
   `RUN_AGENT_SYSTEM_PROMPT_FILE` is set and points to a readable file,
   append its contents. If `RUN_AGENT_SYSTEM_PROMPT_FILE_<NESTING_LEVEL>`
   is set, append its contents. Bump the exported
   `RUN_AGENT_NESTING_LEVEL` by `+1` *before* the agent runs.
   Record whether real content landed (file size > 0) for later use.
   If after these steps the file is still empty, write a single-line
   marker comment so the file has at least one non-whitespace byte
   (see §10 for rationale).
7. **(gemini / junie only) Prompt prepend.** When real system-prompt
   content landed, create `prompt-with-sysp.md` containing
   `<SYSTEM PROMPT>` / `</SYSTEM PROMPT>` delimited content followed
   by the staged prompt, and use that as the prompt fed to the agent
   on stdin. The placeholder-only case MUST NOT trigger the prepend.
8. **Dispatch table.** Build the agent command vector for the chosen
   agent (see §6.1). Reject unknown agents with exit `2`.
9. **Preflight binary check.** If the first element of the command
   vector is not on `PATH`, follow the §3 fail-fast protocol.
10. **Write `cmd.sh`.** Emit an executable replay script that:
    - starts with `#!/bin/bash` and `set -euo pipefail`,
    - `cd`s to the canonicalised `CWD`,
    - re-exports `ENSURE_HANDOFF_DIR`, `RUN_ID`, and `PARENT_RUN_ID`
      when non-empty,
    - invokes the agent command vector with `prompt.md` (or the
      `prompt-with-sysp.md` variant) redirected on stdin.
    All values MUST be `printf %q`-quoted so the script is shell-safe.
11. **Launch.** Unset `CLAUDECODE` first, then execute `cmd.sh` in the
    background with stdout redirected to `agent-stdout.txt` and stderr
    to `agent-stderr.txt`. Record the PID into `pid.txt`.
12. **Write `run-info.txt` (pre-finish portion).** As specified in §5.2.
13. **Print start banner.** As specified in §5.3 steps 1–2.
14. **Spawn the monitor.** Launch the script in `monitor` mode against
    `RUN_DIR` in the background.
15. **Wait.** Block on the agent PID, capture its exit code.
16. **Stop monitor.** Kill and reap the monitor.
17. **Append finish metadata** (`FINISHED`, `EXIT_CODE`) to `run-info.txt`.
18. **Print finish banner + handoff block** (§5.3 steps 3–5).
19. **Optional stderr dump** when `EXIT_CODE != 0` (§5.3 step 6).
20. **Exit** with the agent's exit code.

### 6.1 Agent command vectors

The script MUST construct the launch command for each agent as
follows. All listed flags MUST be present, in the listed order, with
the listed defaults from §4.2 applied unless overridden by the
matching environment variable.

- `claude`:
  `claude -p --model <CLAUDE_MODEL> --effort <CLAUDE_EFFORT> --input-format text --verbose --output-format stream-json --tools default --permission-mode bypassPermissions --append-system-prompt "<contents of system-prompt.md>"`
- `codex`:
  `codex exec --model <CODEX_MODEL> -c model_reasoning_effort=<CODEX_EFFORT> -c model_instructions_file=<system-prompt.md path> --json --dangerously-bypass-approvals-and-sandbox -C <CWD> -`
- `gemini`:
  `gemini --model <GEMINI_MODEL> --output-format stream-json --screen-reader true --approval-mode yolo`
- `junie`:
  `junie --project <CWD> --output-format json --skip-update-check`

Example replay command (one line):

```
bash /path/to/runs/run_20260517-101500-12345/cmd.sh
```

---

## 7. Concurrency & signals

The script MUST run two background processes concurrently with itself:

1. The agent (its PID is the subject of `wait`).
2. A self-spawned `monitor` instance against `RUN_DIR`.

The `monitor` mode MUST:

- Trap `TERM`, `INT`, `HUP` and exit `0` on any of them.
- Redirect its own stdout to stderr (so it does not pollute a
  pipefail-protected `tee` of the parent stdout).
- Every five seconds, compute three values for the run directory:
  number of files (`find -type f`), number of sibling `run_*`
  directories (`find ../ -mindepth 1 -type d -name 'run_*'`), and
  the directory size in KB (`du -sk`).
- Emit a single line of the form
  `MONITOR <UTC-HH:MM:SSZ> files=<N> runs=<M> size=<K>KB` ONLY when
  any of the three values has changed since the last emission.
- Terminate cleanly when the run directory disappears or a signal
  arrives.

Signal handling for the main process:

- `EXIT` trap: best-effort kill of the monitor (`SIGTERM`) and the
  agent (`SIGTERM`). MUST NOT touch `run-info.txt`.
- `TERM` (`SIGTERM`) → exit `143`.
- `INT`  (`SIGINT`)  → exit `130`.
- `HUP`  (`SIGHUP`)  → exit `129`.

On `TERM` / `INT` / `HUP`, the script MUST:

1. Kill and reap the monitor.
2. Send `SIGTERM` to the agent, poll for up to ~1 second
   (five 0.2-second sleeps) for graceful exit, then send `SIGKILL`,
   then `wait` the PID.
3. Remove `pid.txt`.
4. Append `FINISHED=<timestamp>`, `EXIT_CODE=<code>`, and
   `SIGNAL=<sig>` to `run-info.txt` (best-effort; failure MUST NOT abort
   the cleanup).
5. Exit with the code from the table.

Cleanup ordering MUST be: monitor first, then agent, then metadata
flush. The `EXIT` trap MUST be safe under all branches (success,
agent failure, signal) — under the success and agent-failure paths the
monitor and agent are already reaped by the main flow, so the
`EXIT`-trap kills MUST be no-ops.

---

## 8. Handoff contract

The script MUST advertise three handoff files per run:

- `STATUS.md` — a one-line status (e.g. `OK`, `BLOCKED`, `FAILED:…`).
- `RESULT.md` — a human-readable explanation of the outcome.
- `IMPROVEMENTS.md` — agent-suggested improvements and observed
  problems.

The script itself MUST NOT create or populate these files; the staged
prompt asks the agent to write them. Their absolute paths MUST be
exposed three times:

1. As fields in `run-info.txt` (`HANDOFF_STATUS`, `HANDOFF_RESULT`,
   `HANDOFF_IMPROVEMENTS`), which is also echoed twice on stdout
   (start banner and finish banner).
2. As the explicit three-line trailing handoff block on stdout
   (`STATUS:`, `RESULT:`, `IMPROVEMENTS:`).

A caller MUST be able to recover the handoff paths by either path
(grepping `run-info.txt`, grepping the run's stdout, or reading the
trailing block).

---

## 9. Nesting / recursion

The script MUST be safe to invoke recursively (an agent in one run
launching another run via the same script).

On entry, the script:

- MUST snapshot any inbound `RUN_ID` / `RUN_DIR` into `PARENT_RUN_ID`
  / `PARENT_RUN_DIR`.
- MUST unset its own `RUN_ID` / `RUN_DIR` before computing new values.
- MUST `export PARENT_RUN_ID` / `PARENT_RUN_DIR` so the child agent
  process sees the parent linkage.
- MUST set `RUN_AGENT_NESTING_LEVEL` (default `0` when unset) and
  export the incremented value (`NESTING_LEVEL + 1`) before launching
  the agent.

When emitting `run-info.txt`, the script MUST include `PARENT_RUN_ID` and
`PARENT_RUN_DIR` fields when (and only when) they are non-empty.

System-prompt overlays MUST be level-scoped:

- `RUN_AGENT_SYSTEM_PROMPT_FILE` is the *base* overlay; if set, it
  applies at every nesting level.
- `RUN_AGENT_SYSTEM_PROMPT_FILE_<N>` applies only when the script's
  *current* `RUN_AGENT_NESTING_LEVEL` equals `<N>` numerically. Since
  the level is bumped before launching the child agent, a recursive
  invocation reads `RUN_AGENT_NESTING_LEVEL = N+1` and therefore
  matches a different (or no) overlay.

Order of composition: base overlay first, then level-scoped overlay.
Both are appended to the (initially empty) `system-prompt.md`.

---

## 10. Edge cases & invariants

The script MUST behave as follows in the listed edge cases:

- **Empty composed system prompt.** When neither
  `RUN_AGENT_SYSTEM_PROMPT_FILE` nor the level-scoped variant supplies
  any bytes, `system-prompt.md` MUST be replaced with a single
  marker-comment line, semantically empty but non-whitespace. This is
  required for Codex's `model_instructions_file` flag, which rejects
  empty/whitespace files. Other agents MUST tolerate the marker.
- **`HAS_SYSTEM_PROMPT` flag.** The decision whether to prepend a
  `<SYSTEM PROMPT>` block to the user prompt for `gemini` / `junie`
  MUST be based on the *file size before* the placeholder marker is
  written, not on whether an env var is set. Setting the env var to a
  file that is empty MUST NOT leak the marker into the prompt.
- **Agent CLI missing.** Exit `127` with the protocol from §3
  (stderr line, grep-stable token appended to `agent-stderr.txt`).
- **Prompt file not found.** Exit `1` with
  `run-agent.sh: prompt file not found: <argv3>` on stderr.
- **Cwd not found.** Exit `1` with
  `run-agent.sh: cwd not found: <argv2>` on stderr.
- **Unknown agent.** Exit `2` with
  `run-agent.sh: unknown agent: <agent>` on stderr.
- **Fewer than three args.** Exit `64` with the usage banner on stderr.
- **`CLAUDECODE` leakage.** The variable MUST be unset before launching
  the agent process, regardless of which agent is launched.
- **`set -euo pipefail`.** The script MUST run with strict mode; any
  unguarded reference to an unset variable is a bug.
- **`run-info.txt` write order.** The pre-finish portion MUST be flushed
  before `--- run-agent.sh start ---` is printed; the finish portion
  MUST be appended before `--- run-agent.sh finish ---` is printed.
- **Monitor stdout discipline.** Monitor MUST NOT write to the parent
  process's stdout (stdout is redirected to stderr inside monitor).
- **`pid.txt` lifecycle.** It MUST exist while the agent is alive and
  be removed on normal exit and on every signal-driven cleanup.
- **Standalone `cmd.sh`.** Running `bash run_<id>/cmd.sh` from a fresh
  shell MUST reproduce the agent invocation with the same `CWD`, the
  same dispatch-relevant exports, and the same stdin prompt.
- **Pool randomness for `any`.** The pool MUST be `{claude, codex}`
  only; `gemini` and `junie` MUST NOT be picked by `any`.
- **`RUNS_DIR` creation.** When `RUNS_DIR` does not yet exist, the
  script MUST create it (and any missing parents) before resolving it
  to an absolute path.

---

## 11. Non-goals

The script intentionally does NOT:

- Validate the *content* of the user prompt or of the
  `STATUS.md` / `RESULT.md` / `IMPROVEMENTS.md` files. Their presence
  is not enforced; their format is the agent's responsibility.
- Retry, restart, or back off failed agent invocations. The caller (or
  a wrapper such as a stage-flow runner) owns retry policy.
- Aggregate, parse, or transform the agent's stdout/stderr streams
  beyond writing them to the per-run files.
- Manage git state (branches, commits, pushes). It does not run `git`.
- Implement plugin discovery, MCP server lifecycle, or tool gating.
  Those are the agent CLIs' concern.
- Provide a `--help` flag, a `--dry-run` flag, or any flag-style
  invocation. Positional-only.
- Garbage-collect old run directories under `RUNS_DIR`.
- Provide cross-platform Windows support; the script assumes a POSIX
  shell environment with GNU/BSD `find`, `du`, `date -u`, and
  `printf %q` available.
- Authenticate the agent CLIs. Each agent CLI MUST be pre-authenticated
  (e.g. via its own login command) before `run-agent.sh` runs.
- Sandbox the agent. Agents are launched in the caller's target
  working directory with the caller's privileges; isolation is a
  per-run *directory* concept only.
