---
title: "run-agent.sh"
description: "Multi-Agent AI Orchestration for Software Development"
---

**Orchestrate a swarm of AI Agents from your terminal.** Built by [Eugene Petrenko](https://jonnyzzz.com).

---

<div style="display: flex; flex-wrap: wrap; gap: 2rem; margin: 2rem 0;">
<div style="flex: 1; min-width: 300px; padding: 1.5rem;">

### `run-agent.sh`
**The Runner**

A unified shell script that launches AI Agents (Claude, Codex, Gemini) with full isolation and traceability. Each run gets its own folder with captured prompts, stdout/stderr, PID tracking, and exit codes.

```bash
./run-agent.sh claude /path/to/repo prompt.md
./run-agent.sh codex /path/to/repo prompt.md
./run-agent.sh gemini /path/to/repo prompt.md
```

Works best with [THE_PROMPT_v5.md](#the-brain) to orchestrate multi-agent workflows.

[View on GitHub](https://github.com/jonnyzzz/run-agent/blob/main/run-agent.sh)

</div>
<div style="flex: 1; min-width: 300px; padding: 1.5rem;">

### `THE_PROMPT_v5.md`
**The Brain**

A project-independent orchestration workflow that defines roles, stages, quality gates, and communication protocols for AI Agents. It turns raw LLMs into a coordinated development team.

**13 stages** from research to deployment. **7 AI Agent roles** from orchestrator to monitor. **16 parallel AI Agents** max.

Works best with [run-agent.sh](#the-runner) to execute the orchestrated workflow.

[View on GitHub](https://github.com/jonnyzzz/run-agent/blob/main/THE_PROMPT_v5.md)

</div>
</div>

---

## Core Features

### Agentic Swarm

Run up to **16 AI Agents in parallel** -- research, implementation, review, testing, and debugging agents all working on the same codebase simultaneously. The orchestrator coordinates the swarm, splits work by subsystem, and enforces review quorums before commits land.

Each AI Agent has a **fixed role** defined by dedicated prompt files. AI Agents don't improvise -- they follow the staged workflow, log actions to the message bus, and report blockers. The result is deterministic, reproducible multi-agent development.

### Message Bus

Every significant action flows through `MESSAGE-BUS.md` -- an append-only trace log that provides **full observability** into the swarm:

- **FACT** -- Concrete results (test counts, commit hashes, file paths)
- **PROGRESS** -- In-flight status updates
- **DECISION** -- Policy choices with rationale
- **REVIEW** -- Structured code review feedback
- **ERROR** -- Failures that block progress

AI Agents read the bus to coordinate. The orchestrator reads it to decide next steps. You read it to understand what happened.

### Full Traceability

Every AI Agent invocation creates an isolated run folder:

```
runs/run_20260128-194528-12345/
  prompt.md           # Exact prompt sent to the AI Agent
  agent-stdout.txt    # Everything the AI Agent produced
  agent-stderr.txt    # Errors and warnings
  cwd.txt             # Working directory, command, exit code
  run-agent.sh        # Copy of the runner for reproducibility
```

No lost context. No "what did the AI Agent do?" mysteries. Every run is a self-contained, auditable record.

---

## How It Works

```
THE_PROMPT_v5.md                    run-agent.sh
(defines the workflow)              (executes AI Agents)
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

`THE_PROMPT_v5.md` tells AI Agents **what to do** and **in what order**. `run-agent.sh` handles **how to run them** with full artifact capture. The message bus ties it all together with real-time observability.

---

## Quick Start

```bash
git clone https://github.com/jonnyzzz/run-agent.git
cd run-agent

# Launch a single AI Agent
./run-agent.sh claude /path/to/your/repo your-prompt.md

# Launch a swarm -- run multiple AI Agents in parallel
./run-agent.sh claude /path/to/repo research-prompt.md &
./run-agent.sh codex /path/to/repo implement-prompt.md &
./run-agent.sh gemini /path/to/repo review-prompt.md &

# Monitor the swarm
uv run python monitor-agents.py
```

---

## AI Agent Roles

| Role | Prompt File | Purpose |
|------|------------|---------|
| **Orchestrator** | `THE_PROMPT_v5_orchestrator.md` | Coordinates the swarm, spawns sub-agents |
| **Research** | `THE_PROMPT_v5_research.md` | Codebase exploration, no code changes |
| **Implementation** | `THE_PROMPT_v5_implementation.md` | Code changes and tests |
| **Review** | `THE_PROMPT_v5_review.md` | Code review and quality checks |
| **Test** | `THE_PROMPT_v5_test.md` | Test execution and verification |
| **Debug** | `THE_PROMPT_v5_debug.md` | Investigate failures, propose fixes |
| **Monitor** | `THE_PROMPT_v5_monitor.md` | Periodic status checks and restarts |

## Supported AI Agents

| AI Agent | CLI | Flags |
|----------|-----|-------|
| **Claude** | `claude` | `-p --tools default --permission-mode bypassPermissions` |
| **Codex** | `codex` | `exec --dangerously-bypass-approvals-and-sandbox` |
| **Gemini** | `gemini` | `--screen-reader true --approval-mode yolo` |

---

## MCP Steroid Integration

Both `run-agent.sh` and `THE_PROMPT_v5.md` are designed to work with [MCP Steroid](https://mcp-steroid.jonnyzzz.com) -- an MCP server for IntelliJ-based IDEs that provides code review, search, run configurations, builds, inspections, and quality gates to AI Agents.

`THE_PROMPT_v5.md` makes MCP Steroid the **primary tool** for quality gates: no new warnings, no new errors, compilation must succeed before any commit.

---

## License

[Apache License 2.0](https://github.com/jonnyzzz/run-agent/blob/main/LICENSE)

## Author

Created by [Eugene Petrenko](https://jonnyzzz.com) ([@jonnyzzz](https://github.com/jonnyzzz)) -- building the future of AI-assisted software development.
