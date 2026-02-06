# run-agent.sh

**Orchestrate a swarm of AI Agents from your terminal.** Built by [Eugene Petrenko](https://jonnyzzz.com).

Parallel AI. Zero magic. Full control.

---

## `run-agent.sh` -- The Runner

A unified shell script that launches AI Agents (Claude, Codex, Gemini) with full isolation and traceability. Each run gets its own folder with captured prompts, stdout/stderr, PID tracking, and exit codes.

```bash
./run-agent.sh claude /path/to/repo prompt.md
./run-agent.sh codex /path/to/repo prompt.md
./run-agent.sh gemini /path/to/repo prompt.md
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
| `MESSAGE_BUS` | `./MESSAGE-BUS.md` | Append-only trace log |

## Website

[run-agent.jonnyzzz.com](https://run-agent.jonnyzzz.com)

## License

[Apache License 2.0](LICENSE)

## Author

Created by [Eugene Petrenko](https://jonnyzzz.com) ([@jonnyzzz](https://github.com/jonnyzzz)) -- building the future of AI-assisted software development.
