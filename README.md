# run-agent.sh

**Split complex tasks across multiple AI Agents that research, implement, review, and test in parallel -- so each agent stays focused and your codebase gets treated like a real team project.** Built by [Eugene Petrenko](https://jonnyzzz.com).

## What is run-agent.sh?

AI Agents produce better results when they focus on one thing at a time. A single agent tasked with "research the codebase, implement the feature, write tests, review the code, and fix any issues" will lose context, skip steps, or produce shallow work.

`run-agent.sh` lets your agents delegate sub-tasks to new agent processes. The orchestrator breaks work into focused pieces -- research, implementation, review, testing -- and launches a separate agent for each. Each agent works in isolation with a clear, narrow prompt, then reports back through the message bus.

**If a task needs parallel research, isolated experiments, or independent review, this is the runner that makes that practical.**

### Example Prompt

Paste this into Claude, Codex, or Gemini. The root AI Agent will download the orchestration files, create a task workspace, and start delegating work:

```
<PUT YOUR TASK DESCRIPTION HERE>

In order to deliver on the task, you should use https://run-agent.jonnyzzz.com/run-agent.sh script
to start more tasks. You should follow the https://run-agent.jonnyzzz.com/THE_PROMPT_v5.md and
other files relative to it as the main process. Your purpose is to orchestrate and delegate
the work to other run-agent instances that you start; you must not do the work yourself.
So create /loop when necessary to monitor the process. Never stop unless the work is completed.

All your prompts should use the https://run-agent.jonnyzzz.com/MESSAGE-BUS.md as the key
communication principle.

Make sure you download the files locally and use full paths to the downloaded files.
```

---

## `run-agent.sh` -- The Runner

Launch Claude, Codex, or Gemini the same way and keep the evidence. Every run captures the prompt, stdout/stderr, PID, exit code, and working directory so you can see what happened after the agent finishes.

```bash
./run-agent.sh claude /path/to/repo prompt.md
./run-agent.sh codex /path/to/repo prompt.md
./run-agent.sh gemini /path/to/repo prompt.md
./run-agent.sh any /path/to/repo prompt.md  # random agent
```

Works best with [THE_PROMPT_v5.md](#the_prompt_v5md----the-brain) to orchestrate multi-agent workflows.

## `THE_PROMPT_v5.md` -- The Brain

A project-independent orchestration workflow that defines roles, stages, quality gates, and communication protocols for AI Agents. It turns raw LLMs into a coordinated development team.

**13 stages** from research to deployment. **7 agent roles** from orchestrator to monitor. **16 parallel agents** max.

Works best with [run-agent.sh](#run-agentsh----the-runner) to execute the orchestrated workflow.

---

## Core Features

### Agentic Swarm

Run up to **16 AI Agents in parallel** -- research, implementation, review, testing, and debugging agents all working on the same codebase simultaneously. The orchestrator agent coordinates the swarm, splits work by subsystem, and enforces review quorums before commits land.

Each agent has a **fixed role** defined by dedicated prompt files. Agents don't improvise -- they follow the staged workflow, log actions to the message bus, and report blockers. The result is deterministic, reproducible multi-agent development.

### Message Bus

Every significant action flows through `MESSAGE-BUS.md` -- an append-only trace log that provides **full observability** into the swarm. Agents write structured entries:

- **FACT**: Concrete results (test counts, commit hashes, file paths)
- **PROGRESS**: In-flight status updates
- **DECISION**: Policy choices with rationale
- **REVIEW**: Structured code review feedback
- **ERROR**: Failures that block progress

The message bus is the single source of truth. Agents read it to coordinate, the orchestrator reads it to decide next steps, and you read it to understand what happened.

### Full Traceability

Every agent invocation creates an isolated run folder:

```
runs/run_20260128-194528-12345/
  prompt.md           # Exact prompt sent to the agent
  agent-stdout.txt    # Everything the agent produced
  agent-stderr.txt    # Errors and warnings
  cwd.txt             # Working directory, command, exit code
  run-agent.sh        # Copy of the runner for reproducibility
```

No lost context. No "what did the agent do?" mysteries. Every run is a self-contained, auditable record.

---

## How They Work Together

```
THE_PROMPT_v5.md                    run-agent.sh
(defines the workflow)              (executes agents)
         |                                |
         |-- Stage 0: Cleanup             |-- ./run-agent.sh claude ...
         |-- Stage 2: Research    ------> |-- ./run-agent.sh codex ...
         |-- Stage 5: Implement   ------> |-- ./run-agent.sh gemini ...
         |-- Stage 6: Quality Gate        |
         |-- Stage 9: Review      ------> |-- ./run-agent.sh claude ...
         |-- Stage 12: Monitor            |-- (all outputs in runs/)
                                          |
                MESSAGE-BUS.md  <---------|  (append-only trace log)
```

`THE_PROMPT_v5.md` tells agents **what to do** and **in what order**. `run-agent.sh` handles **how to run them** with full artifact capture. The message bus ties it all together with real-time observability.

## Quick Start

```bash
git clone https://github.com/jonnyzzz/run-agent.git
cd run-agent

# Launch a Claude agent
./run-agent.sh claude /path/to/your/repo your-prompt.md

# Launch a swarm -- run multiple agents in parallel
./run-agent.sh claude /path/to/repo research-prompt.md &
./run-agent.sh codex /path/to/repo implement-prompt.md &
./run-agent.sh gemini /path/to/repo review-prompt.md &

# Monitor the swarm
uv run python monitor-agents.py
```

## Website Build (Docker Compose)

Build the static site in Docker (this is the standard project flow):

```bash
UID="$(id -u)" GID="$(id -g)" docker compose run --rm hugo-build
```

Run a local preview server:

```bash
UID="$(id -u)" GID="$(id -g)" docker compose up hugo-serve
```

Compose uses Hugo `--forceSyncStatic` so static assets are recopied into `public/` on each build and serve run.

## Agent Roles (defined in THE_PROMPT_v5.md)

| Role | Prompt File | Purpose |
|------|------------|---------|
| **Orchestrator** | `THE_PROMPT_v5_orchestrator.md` | Coordinates full workflow, spawns sub-agents |
| **Research** | `THE_PROMPT_v5_research.md` | Codebase exploration, no code changes |
| **Implementation** | `THE_PROMPT_v5_implementation.md` | Code changes and tests |
| **Review** | `THE_PROMPT_v5_review.md` | Code review and quality checks |
| **Test** | `THE_PROMPT_v5_test.md` | Test execution and verification |
| **Debug** | `THE_PROMPT_v5_debug.md` | Investigate failures, propose fixes |
| **Monitor** | `THE_PROMPT_v5_monitor.md` | Periodic status checks and restarts |

## Supported Agents (launched by run-agent.sh)

| Agent | CLI | Flags |
|-------|-----|-------|
| **Claude** | `claude` | `-p --tools default --permission-mode bypassPermissions` |
| **Codex** | `codex` | `exec --dangerously-bypass-approvals-and-sandbox` |
| **Gemini** | `gemini` | `--screen-reader true --approval-mode yolo` |

## The 13-Stage Development Flow

0. **Cleanup** - Read project docs, prepare orchestration files
1. **Read local docs** - Understand project conventions
2. **Multi-agent research** - Parallel research and implementation scoping
3. **Select tasks** - Choose actionable work (low-hanging fruit first)
4. **Validate tests/build** - Confirm baseline passes
5. **Implement changes** - Code + tests
6. **Quality gate** - Verify no new warnings/errors via [MCP Steroid](https://mcp-steroid.jonnyzzz.com)
7. **Re-run tests** - Verify changes
8. **Research authorship** - Align with existing patterns
9. **Commit review** - Cross-agent review quorum
10. **Rebase/rebuild** - Clean history, verify compilation
11. **Push/preflight** - Feature branch, code review
12. **Monitor/fix** - Watch CI and apply fixes

## MCP Steroid Integration

Both `run-agent.sh` and `THE_PROMPT_v5.md` are designed to work with [MCP Steroid](https://mcp-steroid.jonnyzzz.com) - an MCP server for IntelliJ-based IDEs that provides code review, search, run configurations, builds, inspections, and quality gates to AI Agents.

## Monitoring

```bash
# Live console dashboard with color-coded agent logs
uv run python monitor-agents.py

# Background watchers
./watch-agents.sh &          # 60-second polling
nohup ./monitor-agents.sh &  # 10-minute polling

# Status loop -- append swarm status to message bus
./status-loop.sh &           # Every 60 seconds
./status-loop-5m.sh &        # Every 5 minutes
```

## Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `RUNS_DIR` | `./runs` | Directory for agent run folders |
| `RUN_AGENT_AGENTS` | all built-in | Comma-separated list of available agents (e.g. `claude,codex`) |

### Exported to agent process

| Variable | Description |
|----------|-------------|
| `RUNS_DIR` | Absolute path to the runs directory |
| `MESSAGE_BUS` | Absolute path to `MESSAGE-BUS.md` (inside `RUNS_DIR`) |
| `RUN_ID` | Unique run identifier for this invocation |
| `PROMPT` | Absolute path to the copied prompt file |

`CLAUDECODE` is explicitly unset before spawning to prevent leaking nested runtime context.

## Website

[run-agent.jonnyzzz.com](https://run-agent.jonnyzzz.com)

## License

[Apache License 2.0](LICENSE)

## Author

Created by [Eugene Petrenko](https://jonnyzzz.com) ([@jonnyzzz](https://github.com/jonnyzzz)) -- building the future of AI-assisted software development.
