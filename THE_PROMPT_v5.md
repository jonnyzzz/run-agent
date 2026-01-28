# THE_PROMPT_v5

"start agent", or "start sub agent" in this document always means to start the repo-provided agent runner or command line for the chosen agent.

## Purpose
This document captures a project-independent orchestration workflow that can be applied to any codebase while keeping the IntelliJ MCP Steroid server as the primary tool.

## Project Variables
Use these placeholders to avoid hardcoded paths:
- <PROJECT_ROOT> - absolute path to the repo root
- <RUNS_DIR> - <PROJECT_ROOT>/runs
- <MESSAGE_BUS> - <PROJECT_ROOT>/MESSAGE-BUS.md
- <ISSUES_FILE> - <PROJECT_ROOT>/ISSUES.md

## Core Principles
- Root agent orchestrates; sub-agents do codebase work in the target repo.
- If the target codebase is outside <PROJECT_ROOT>, the root agent must not modify it directly; use sub-agents with CWD set to the target repo.
- Log significant actions to <MESSAGE_BUS> (append-only) and blockers to <ISSUES_FILE>.
- IntelliJ MCP Steroid review is required for changes; compilation/build must succeed before completion when builds/tests exist.
- Prefer IntelliJ MCP Steroid for search, review, run configs, and builds/tests; CLI fallback only via project-provided scripts or wrappers.
- Avoid committing IDE-generated metadata unless explicitly required; keep such changes isolated.
- Follow project commit rules; do not invent new formats.
- Precedence (high to low): Required Development Flow > project-specific AGENTS/Instructions (only when explicitly conflicting) > this document > Standard Workflow template. Unresolved conflicts require research plus a logged DECISION.
- If an auxiliary MCP server fails to start, treat as non-blocking and continue with IntelliJ MCP Steroid.
- If a branch is dirty due to IDE or tool artifacts, avoid rebasing until cleaned; create a cleanup task to revert artifacts and add ignore rules.

## Known Environment or Tool Issues
Maintain a short list of recurring MCP/tool startup issues and required fallbacks in project docs; treat these as non-blocking unless they prevent core IntelliJ MCP Steroid workflows.

## Role-Specific Prompts (Required)
Each agent run must use a dedicated role prompt file. Do not improvise or redefine roles.
Recommended role files (relative to project root):
- THE_PROMPT_v5_orchestrator.md
- THE_PROMPT_v5_research.md
- THE_PROMPT_v5_implementation.md
- THE_PROMPT_v5_review.md
- THE_PROMPT_v5_test.md
- THE_PROMPT_v5_debug.md
- THE_PROMPT_v5_monitor.md (status-loop prompt; agent may update when improving monitoring)
When creating a <RUNS_DIR>/run_XXX/prompt.md, copy the relevant role file verbatim and append task-specific instructions. Always use absolute paths for all .md file references inside the prompt so sub-agents do not search for files. If role prompt files do not exist, create them from the base template or map to existing versioned role prompts via a project-specific override, and log the decision to <MESSAGE_BUS>.

## Parallelism
- Max parallel agents: 16.
- Use parallelism to separate research, implementation, review, and testing.
- If the agent thread limit is reached, close completed agents and retry spawns.

## Agent Execution and Traceability (Required)
All agent runs must use a unified runner script when available (for example, ./run-agent.sh in this repo). The runner must create a new run folder and enforce consistent file names. If no runner exists, manually create the run folder and required artifacts, and log the deviation to <MESSAGE_BUS>.

Required steps for every agent run:
1. Prepare a prompt file (any path). The orchestrator prepares full prompt text for each sub-agent and uses absolute paths for all .md references.
2. Run the unified runner: ./run-agent.sh [agent] <cwd> [prompt_file] (or the equivalent in your repo).
3. The runner creates a new run folder under <RUNS_DIR>/ with id format run_YYYYMMDD-HHMMSS-<pid>.
4. The runner copies the prompt into <RUNS_DIR>/<run_id>/prompt.md.
5. The runner writes <RUNS_DIR>/<run_id>/cwd.txt with the workdir and command line.
6. The runner writes <RUNS_DIR>/<run_id>/agent-stdout.txt and agent-stderr.txt.
7. The runner copies itself into <RUNS_DIR>/<run_id>/run-agent.sh for traceability (or records the runner command).
8. The runner writes <RUNS_DIR>/<run_id>/pid.txt and prints PID to stdout.
9. The runner blocks until the agent completes, then removes pid.txt, writes EXIT_CODE=... into cwd.txt, and exits.
10. If a background start produces no logs within 30s, re-run in the foreground to confirm startup and PID logging.

All inputs/outputs must be persisted under the same <RUNS_DIR>/run_XXX/ folder (prompt, logs, artifacts). If your repo uses a different layout, ensure the equivalent artifacts are captured.

### Status Checks
- Use pid.txt (while present) to verify running agents (ps -p <pid>). If shell access is restricted, read pid.txt, cwd.txt, and recent log files via IntelliJ MCP Steroid instead.
- For completed runs, pid.txt is removed; use EXIT_CODE= in <RUNS_DIR>/<run_id>/cwd.txt to confirm finished status.
- Optional watcher: run ./watch-agents.sh to poll every 60s and log to <RUNS_DIR>/agent-watch.log.
- Long-interval watcher: run ./monitor-agents.sh to poll every 10 minutes and log to <RUNS_DIR>/agent-watch.log.
- If using the long-interval watcher, start it via nohup and record PID:
  - PID file: <RUNS_DIR>/agent-watch.pid
  - stdout/stderr: <RUNS_DIR>/agent-watch.out

### Monitoring (Console UI)
Use the monitor script (if present) to see live output with [run_xxx] prefixes and a compact header showing running/finished/unknown counts.
- Run: uv run python monitor-agents.py
- The monitor reads <RUNS_DIR> and streams both agent-stdout.txt and agent-stderr.txt.
If the monitor has configurable defaults (poll interval, summary interval/lines), record them in project docs to keep monitoring reproducible.

### Helper Scripts (if present)
- run-agent.sh - unified runner
- run-agent-tests.sh - validates agents (basic response + MCP tool listing)
- test-claude-run.sh - validates Claude startup with closed stdin
- watch-agents.sh - 60s polling loop for PID status
- monitor-agents.sh - 10-minute polling loop (background)
- status-loop.sh - legacy 60s polling loop (optional)
- status-loop-5m.sh - legacy 5-minute log loop (optional)
- monitor-agents.py - live console monitor with [run_xxx] prefixes and a compact header

## Required Development Flow (Agent Stages)
Each bullet below is a distinct agent stage. The root agent selects the agent type (Codex/Claude/Gemini) at random unless statistics strongly indicate a better choice. Any failure must be logged to <MESSAGE_BUS> (and <ISSUES_FILE> if blocking), and the flow restarts from the beginning (or from a root-selected stage if appropriate). Parallel execution is allowed where it does not violate dependencies.

1. Stage 0: Cleanup
   Look at related project files like MESSAGE-BUS.md, AGENTS.md, Instructions.md, FACTS.md, ISSUES.md. Summarize or append new entries; do not edit MESSAGE-BUS history.

2. Stage 1: Read local docs
   Read AGENTS.md and all relevant .md files using absolute paths.

3. Stage 2: Research task with multi-agent context
   Run at least two agents in parallel (research and implementation) to scope the task. Use the project's agent startup docs to confirm flags and tool availability.

4. Stage 3: Select tasks (low-hanging fruit first)
   Choose actionable tasks based on IntelliJ MCP Steroid exploration of the codebase.

5. Stage 4: Select and validate tests/build
   Pick relevant unit/integration tests and verify they pass in IntelliJ MCP Steroid; also ensure the project builds in IntelliJ MCP Steroid when builds/tests exist. If no tests/builds apply, log N/A to <MESSAGE_BUS>. Long-running CI can run asynchronously.

6. Stage 5: Implement changes and tests
   Make code changes and add/update tests.

7. Stage 6: IntelliJ MCP quality gate
   Verify no new warnings/errors/suggestions in IntelliJ MCP Steroid.

8. Stage 7: Re-run tests in IntelliJ MCP
   Re-run relevant tests in IntelliJ MCP Steroid.

9. Stage 8: Research authorship and patterns
   Use git annotate/blame and project review tools to identify maintainers and align with existing patterns.

10. Stage 9: Commit guideline review and cross-agent code review
   Validate commit rules. For code review, require a quorum of at least two independent agents for non-trivial/multi-line changes; trivial changes can be handled by a single root-review agent. If the project mandates more reviewers, follow that requirement.

11. Stage 10: Rebase, rebuild, and tests
    Squash or split into logical commits, rebase on latest main/master once the workspace is clean, verify compilation in IntelliJ MCP Steroid, and re-run related tests.

12. Stage 11: Push, preflight, and code review
    Push to a feature branch, run the project's preflight gate (for example, safe push) when applicable, create a code review, and log all links to MESSAGE-BUS.md. If preflight/review is not applicable, log N/A to <MESSAGE_BUS>.

13. Stage 12: Monitor and apply fixes
    Monitor preflight and review results and apply required fixes; log failures and restart flow as needed.

## Agent Startup (No-Sandbox and Auto-Approve)
- Research and document how to start each supported agent without sandbox and with auto-approve in your environment, if permitted by policy.
- Instruct agents to make decisions autonomously.
- Each agent run must write inputs/outputs under the active <RUNS_DIR>/run_XXX/ folder.
- If you use Claude CLI, use --permission-mode bypassPermissions (per current configuration) and pass the prompt as the final argument when stdin is closed.
- Claude MCP tool name may appear as mcp__intellij-steroid__steroid_execute_code (hyphenated server); accept that in verification checks.

## Root Agent Role
- Create and execute staged scripts (uv run python or bash) to run each agent stage above.
- Review each agent outcome to decide when/where to advance.
- If a contradiction is found across docs, this flow overrides; start a research agent, decide based on project specifics, and log options to MESSAGE-BUS.md.
- For complex changes, split work by subsystem and start sub-agents aligned to the plan; each sub-agent runs the same staged flow recursively for its scope.
- Use git commits as an information handoff between agents, in addition to MESSAGE-BUS.md and unchanged files.
- For planning: run 5-10 iterations to converge on the task plan; log each iteration outcome to MESSAGE-BUS.md.
- For review planning: run 5-10 iterations to converge on the review plan; log each iteration outcome to MESSAGE-BUS.md.

## Files and Artifacts
- AGENTS.md (root and subsystem) governs conventions.
- Instructions.md lists repo locations and tool paths.
- <RUNS_DIR>/run_XXX/ contains prompt/log artifacts (prompt.md, agent-stdout.txt, agent-stderr.txt, cwd.txt; optional run.log).
- MESSAGE-BUS.md is the main trace log; ISSUES.md is the blocker log.
- FACTS.md (if used) records verified facts and decisions.
- THE_PLAN.md is the execution plan.
- THE_PROMPT_v5.md is the primary entry point for new agents.

## References (Start Here)
New agents should begin with:
1. THE_PROMPT_v5.md (this file)
2. AGENTS.md
3. Instructions.md
4. THE_PLAN.md
5. A project development guide if present (for example, DEVELOPMENT-GUIDE.md)

## Tools and Access
- IntelliJ MCP Steroid is the primary tool for code review, search, run configurations, and builds. Use it for analysis and file inspection when shell access is restricted.
- Prefer IntelliJ MCP Steroid over raw CLI workflows whenever possible.
- Use no-sandbox runs when workspace sandbox blocks git or file writes outside the repo, but prefer standard sandboxed runs for safety.
- Use project-specific CLI tools for review/preflight metadata; record their paths in Instructions.md.

## Standard Workflow
If this template conflicts with the Required Development Flow, the Required Development Flow wins.

### Phase 0: Bootstrap
1. Read AGENTS.md, Instructions.md, and the current plan (THE_PLAN.md).
2. Create a new <RUNS_DIR>/run_XXX/ folder (via run-agent) and keep any extra orchestration notes there if needed.
3. Log initial DECISIONs in MESSAGE-BUS.md.

### Phase 1: Spawn Agents (parallel)
- Spawn implementation, research, and review agents as needed.
- Assign tasks explicitly; require logging to MESSAGE-BUS.md and ISSUES.md.

### Phase 2: Implement Task-Specific Change
1. Identify the change target(s) and scope.
2. Run the relevant tests in IntelliJ MCP Steroid and record test list and counts.
3. Implement the change using existing patterns.
4. Re-run and verify test list parity and passing status.
5. Inspect in IntelliJ MCP Steroid (file problems, find usages).
6. Build in IntelliJ MCP Steroid when builds exist (compilation must succeed).
7. Commit following project rules when committing is required (include runId in the body if required).

### Phase 3: Reviews
- Collect review feedback from multiple agents.
- Resolve blockers and re-run tests if needed.
- Log all review outcomes in MESSAGE-BUS.md.

### Phase 4: Completion
- Verify IntelliJ MCP Steroid review done and compilation succeeded.
- Confirm tests for changed components pass.
- Update ISSUES.md (resolve or document known failures).
- Provide final summary to the user with links and commit hashes when available.

## Communication Protocol (Summary)
- FACT: concrete results (tests, commits, links).
- PROGRESS: in-flight status.
- DECISION: choices and policy updates.
- REVIEW: structured feedback.
- ERROR: failures that block progress.

## Known Constraints
- If the main repo is large or access is restricted, use sub-agents with the correct cwd.
- If MCP automation is blocked by modal dialogs, fall back to IDE UI run (for example, a keyboard shortcut) and scrape results.
- If build/test failures are known, log to ISSUES.md and request acknowledgment.
