---
title: "run-agent.sh"
description: "Multi-Agent AI Orchestration for Software Development"
featured_image: "/images/hero.png"
---

**Two tools. One framework. Ship code with parallel AI agents.**

---

<div style="display: flex; flex-wrap: wrap; gap: 2rem; margin: 2rem 0;">
<div style="flex: 1; min-width: 300px; border: 2px solid #00bcd4; border-radius: 8px; padding: 1.5rem;">

### `run-agent.sh`
**The Runner**

A unified shell script that launches AI agents (Claude, Codex, Gemini) with full isolation and traceability. Each run gets its own folder with captured prompts, stdout/stderr, PID tracking, and exit codes.

```bash
./run-agent.sh claude /path/to/repo prompt.md
./run-agent.sh codex /path/to/repo prompt.md
./run-agent.sh gemini /path/to/repo prompt.md
```

Works best with [THE_PROMPT_v5.md](#the_prompt_v5md---the-brain) to orchestrate multi-agent workflows.

[View run-agent.sh on GitHub](https://github.com/jonnyzzz/run-agent/blob/main/run-agent.sh)

</div>
<div style="flex: 1; min-width: 300px; border: 2px solid #1a237e; border-radius: 8px; padding: 1.5rem;">

### `THE_PROMPT_v5.md`
**The Brain**

A project-independent orchestration workflow that defines roles, stages, quality gates, and communication protocols for AI agents. It turns raw LLMs into a coordinated development team.

**13 stages** from research to deployment. **7 agent roles** from orchestrator to monitor. **16 parallel agents** max.

Works best with [run-agent.sh](#run-agentsh---the-runner) to execute the orchestrated workflow.

[View THE_PROMPT_v5.md on GitHub](https://github.com/jonnyzzz/run-agent/blob/main/THE_PROMPT_v5.md)

</div>
</div>

---

## How They Work Together

```
THE_PROMPT_v5.md                    run-agent.sh
(defines the workflow)              (executes agents)
         │                                │
         ├── Stage 0: Cleanup             ├── ./run-agent.sh claude ...
         ├── Stage 2: Research    ──────► ├── ./run-agent.sh codex ...
         ├── Stage 5: Implement   ──────► ├── ./run-agent.sh gemini ...
         ├── Stage 6: Quality Gate        │
         ├── Stage 9: Review      ──────► ├── ./run-agent.sh claude ...
         └── Stage 12: Monitor            └── (all outputs in runs/)
```

`THE_PROMPT_v5.md` tells agents **what to do** and **in what order**. `run-agent.sh` handles **how to run them** with full artifact capture. Together, they turn your terminal into a multi-agent development shop.

---

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

---

## The 13-Stage Development Flow

Defined in `THE_PROMPT_v5.md`, executed by `run-agent.sh`:

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

---

## Quick Start

### 1. Get the files

```bash
git clone https://github.com/jonnyzzz/run-agent.git
cd run-agent
```

### 2. Run an agent

```bash
# Run a Claude agent with a prompt
./run-agent.sh claude /path/to/your/repo your-prompt.md

# Run a Codex agent
./run-agent.sh codex /path/to/your/repo your-prompt.md

# Run a Gemini agent
./run-agent.sh gemini /path/to/your/repo your-prompt.md
```

### 3. Monitor agents

```bash
# Live console dashboard
uv run python monitor-agents.py

# Background PID watchers
./watch-agents.sh &          # 60-second polling
nohup ./monitor-agents.sh &  # 10-minute polling

# Message bus status loop
./status-loop.sh &           # Append status every 60s
```

### 4. Check run artifacts

Each agent run creates a folder under `runs/` with:
- `prompt.md` - the input prompt
- `agent-stdout.txt` / `agent-stderr.txt` - captured output
- `cwd.txt` - execution context and exit code
- `pid.txt` - PID tracking (removed on completion)

---

## MCP Steroid Integration

Both `run-agent.sh` and `THE_PROMPT_v5.md` are designed to work with [MCP Steroid](https://mcp-steroid.jonnyzzz.com) - an MCP server for IntelliJ-based IDEs that provides code review, search, run configurations, builds, inspections, and quality gates to AI agents.

`THE_PROMPT_v5.md` makes MCP Steroid the **primary tool** for:
- Code inspections and Find Usages
- Running tests and builds
- Quality gate verification (no new warnings/errors)
- File navigation and search

---

## All Files

```
run-agent.sh                  # The Runner - unified agent launcher
THE_PROMPT_v5.md              # The Brain - master orchestration guide
THE_PROMPT_v5_*.md            # Role-specific prompts (7 roles)
monitor-agents.py             # Live console monitor
monitor-agents.sh             # Background PID monitor (10min)
watch-agents.sh               # Background PID monitor (60s)
status-loop.sh                # Message bus status appender (60s)
status-loop-5m.sh             # Message bus status appender (5min)
run-agent-tests.sh            # Integration tests
test-claude-run.sh            # Claude sanity check
```

## Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `RUNS_DIR` | `./runs` | Directory for agent run folders |
| `MESSAGE_BUS` | `./MESSAGE-BUS.md` | Append-only trace log |

---

## License

[Apache License 2.0](https://github.com/jonnyzzz/run-agent/blob/main/LICENSE)

## Author

[Eugene Petrenko](https://jonnyzzz.com) ([@jonnyzzz](https://github.com/jonnyzzz))
